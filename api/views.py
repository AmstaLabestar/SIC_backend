import uuid
from django.db import transaction
from rest_framework import viewsets, status, generics, mixins
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.pagination import PageNumberPagination

from .permissions import IsApprovedAgent

from core.models import Transaction, CompensationDetail, Puce, Agent
from .serializers import (
    DepositSerializer, WithdrawSerializer, ConversionSerializer, 
    AgentSerializer, PuceSerializer, TransactionSerializer
)
from .services.compensation_engine import CompensationEngine

from django.utils import timezone
from datetime import timedelta
from core.tasks import check_transaction_timeout
from core.utils import log_activity

class AgentProfileView(generics.RetrieveAPIView):
    serializer_class = AgentSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        # Ensure the user has an agent profile
        agent, created = Agent.objects.get_or_create(user=self.request.user)
        return agent

class PuceViewSet(viewsets.ModelViewSet):
    serializer_class = PuceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        agent = getattr(self.request.user, 'agent_profile', None)
        if agent:
            return Puce.objects.filter(agent=agent)
        return Puce.objects.none()

    def perform_create(self, serializer):
        agent, created = Agent.objects.get_or_create(user=self.request.user)
        serializer.save(agent=agent)

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class TransactionViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = TransactionSerializer
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        agent = getattr(self.request.user, 'agent_profile', None)
        if agent:
            return Transaction.objects.filter(agent=agent).order_by('-created_at')
        return Transaction.objects.none()

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated, IsApprovedAgent])
    def deposit(self, request):
        serializer = DepositSerializer(data=request.data)
        if serializer.is_valid():
            agent = request.user.agent_profile
            try:
                tx = CompensationEngine.create_compensated_transaction(
                    agent, 'DEPOT', 
                    serializer.validated_data['amount'],
                    serializer.validated_data['target_operator'],
                    serializer.validated_data['target_phone_number']
                )
                log_activity(agent=agent, action="TX_DEPOT_INITIATED", description=f"Dépôt de {tx.amount} vers {tx.target_phone_number} initié.", level="INFO")
                return Response({'message': 'Dépôt initié', 'transaction_id': tx.id})
            except ValueError as e:
                log_activity(agent=agent, action="TX_DEPOT_FAILED", description=f"Échec création dépôt: {str(e)}", level="WARNING")
                return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated, IsApprovedAgent])
    def withdraw(self, request):
        serializer = WithdrawSerializer(data=request.data)
        if serializer.is_valid():
            agent = request.user.agent_profile
            # Retrait: Pas de compensation, l'agent encaisse le cash et transfère de la monnaie électronique
            return Response({'message': 'Retrait non implémenté pour le moment'}, status=status.HTTP_501_NOT_IMPLEMENTED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated, IsApprovedAgent])
    def conversion(self, request):
        serializer = ConversionSerializer(data=request.data)
        if serializer.is_valid():
            agent = request.user.agent_profile
            amount = serializer.validated_data['amount']
            source_id = serializer.validated_data['source_puce_id']
            target_id = serializer.validated_data['target_puce_id']
            
            try:
                source_puce = Puce.objects.get(id=source_id, agent=agent)
                target_puce = Puce.objects.get(id=target_id, agent=agent)
            except Puce.DoesNotExist:
                return Response({'error': 'Puce invalide'}, status=status.HTTP_400_BAD_REQUEST)
                
            if source_puce.balance < amount:
                return Response({'error': 'Solde insuffisant sur la puce source'}, status=status.HTTP_400_BAD_REQUEST)

            with transaction.atomic():
                tx = Transaction.objects.create(
                    agent=agent, type='SWAP', status='PENDING',
                    target_operator=target_puce.operator, target_phone_number=str(target_puce.id),
                    amount=amount, is_compensated=False
                )
                ref = f"CPAY_{uuid.uuid4().hex[:8].upper()}"
                CompensationDetail.objects.create(
                    transaction=tx, puce=source_puce, amount_deducted=amount,
                    status='PENDING', cinetpay_ref=ref
                )
            log_activity(agent=agent, action="TX_CONVERSION_INITIATED", description=f"Conversion de {amount} initiée.", level="INFO")
            return Response({'message': 'Conversion initiée', 'transaction_id': tx.id})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    # Webhook public pour CinetPay (pas d'auth requise idéalement, mais on le garde simple)
    @action(detail=False, methods=['post'], permission_classes=[])
    def webhook(self, request):
        ref = request.data.get('cinetpay_ref')
        if not ref:
            return Response({'error': 'Missing ref'}, status=400)
            
        try:
            detail = CompensationDetail.objects.select_related('transaction').get(cinetpay_ref=ref)
        except CompensationDetail.DoesNotExist:
            return Response({'error': 'Not found'}, status=404)
            
        if detail.status != 'PENDING':
            return Response({'message': 'Already processed'})
            
        with transaction.atomic():
            detail.status = 'SUCCESS'
            detail.save()
            
            # Déduire le solde
            puce = detail.puce
            puce.balance -= detail.amount_deducted
            puce.save()
            
            # Vérifier si toute la transaction est complète
            tx = detail.transaction
            all_details = tx.compensation_details.all()
            if all(d.status == 'SUCCESS' for d in all_details):
                tx.status = 'COMPLETED'
                tx.save()
                
                if tx.type == 'SWAP':
                    target_puce = Puce.objects.get(id=tx.target_phone_number)
                    target_puce.balance += tx.amount
                    target_puce.save()
                    log_activity(agent=tx.agent, action="TX_CONVERSION_COMPLETED", description=f"Conversion de {tx.amount} complétée.", level="SUCCESS")
                else:
                    log_activity(agent=tx.agent, action="TX_COMPLETED", description=f"Transaction {tx.type} de {tx.amount} complétée.", level="SUCCESS")
                    
        return Response({'success': True})
