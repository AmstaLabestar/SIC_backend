"""
API REST pour SIC - Vues et ViewSets sécurisé
"""
import uuid
import hmac
import hashlib
import os
import logging
from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
from rest_framework import viewsets, status, generics, mixins
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny, IsAdminUser
from rest_framework.pagination import PageNumberPagination
from rest_framework.throttling import ScopedRateThrottle

from django.conf import settings
from .permissions import IsApprovedAgent
from .serializers import (
    DepositSerializer, WithdrawSerializer, ConversionSerializer,
    AgentSerializer, PuceSerializer, TransactionSerializer, RegisterSerializer,
    CustomTokenObtainPairSerializer, PinSetupSerializer, PinVerifySerializer,
    BiometricRegisterSerializer, BiometricLoginSerializer
)
from .services.compensation_engine import (
    CompensationEngine, CommissionCalculator, TransactionValidator
)
from .services.limits import LimitsEngine
from core.models import Transaction, CompensationDetail, Puce, Agent, BiometricDevice
from core.tasks import check_transaction_timeout
from core.utils import log_activity

logger = logging.getLogger('sic.transactions')


class LoginRateThrottle(ScopedRateThrottle):
    """Limite le nombre de tentatives de connexion."""
    scope = 'login'


class TransactionRateThrottle(ScopedRateThrottle):
    """Limite le nombre de transactions."""
    scope = 'transaction'


class PinRateThrottle(ScopedRateThrottle):
    """Limite le nombre de tentatives PIN."""
    scope = 'pin'


class StandardResultsSetPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class RegisterView(generics.CreateAPIView):
    """
    Vue d'enregistrement d'un nouvel agent.

    POST /api/auth/register/
    {
        "username": "john_doe",
        "email": "john@example.com",
        "password": "secure_password",
        "password_confirm": "secure_password",
        "phone_number": "+224621234567",
        "first_name": "John",
        "last_name": "Doe"
    }
    """
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'register'

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            log_activity(
                agent=user.agent_profile,
                action="AGENT_REGISTERED",
                description=f"Nouvel agent enregistré: {user.username}",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response({
                'message': 'Inscription réussie. Votre compte est en attente de validation KYC.',
                'user_id': user.id,
                'phone_number': user.agent_profile.phone_number
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AgentProfileView(generics.RetrieveAPIView):
    """
    Vue pour récupérer le profil de l'agent connecté.

    GET /api/auth/profile/
    """
    serializer_class = AgentSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        agent = getattr(self.request.user, 'agent_profile', None)
        if not agent:
            # Créer le profil si inexistant (au cas où)
            agent, created = Agent.objects.get_or_create(user=self.request.user)
        return agent


class AccountLimitsView(generics.GenericAPIView):
    """
    Limites KYC du compte connecté (palier, plafonds, consommation, reste).

    GET /api/auth/limits/
    Permet à l'app d'afficher « il vous reste X aujourd'hui » et d'inviter à
    l'upgrade KYC. Les montants None signifient « illimité » (palier complet).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        agent = getattr(request.user, 'agent_profile', None)
        if not agent:
            return Response({'error': 'Profil introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        summary = LimitsEngine.summary(agent)
        # Sérialiser les Decimal/None en chaînes (ou null) pour le JSON.
        payload = {
            k: (None if v is None else str(v)) if k != 'tier' else v
            for k, v in summary.items()
        }
        return Response(payload, status=status.HTTP_200_OK)


class PuceViewSet(viewsets.ModelViewSet):
    """
    VueSet pour gérer les puces SIM de l'agent.

    GET /api/puces/           - Liste des puces
    POST /api/puces/          - Ajouter une puce
    GET /api/puces/{id}/     - Détail d'une puce
    PUT /api/puces/{id}/      - Modifier une puce
    DELETE /api/puces/{id}/   - Supprimer une puce
    POST /api/puces/{id}/topup/ - Recharger une puce (admin only)
    """
    serializer_class = PuceSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        agent = getattr(self.request.user, 'agent_profile', None)
        if agent:
            return Puce.objects.filter(agent=agent).order_by('-created_at')
        return Puce.objects.none()

    def perform_create(self, serializer):
        agent, created = Agent.objects.get_or_create(user=self.request.user)
        # Vérifier le nombre maximum de puces par agent
        current_count = Puce.objects.filter(agent=agent).count()
        max_puces = int(os.environ.get('MAX_PUCES_PER_AGENT', 5))

        if current_count >= max_puces:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(f"Vous avez atteint le nombre maximum de puces ({max_puces}).")

        # Valider l'opérateur
        operator = serializer.validated_data.get('operator', '').upper()
        if operator not in TransactionValidator.VALID_OPERATORS:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(f"Opérateur invalide: {operator}")

        # Vérifier si le numéro n'est pas déjà utilisé
        phone = serializer.validated_data.get('phone_number', '')
        if Puce.objects.filter(agent=agent, phone_number=phone, operator=operator).exists():
            from rest_framework.exceptions import ValidationError
            raise ValidationError(f"Cette puce ({operator} {phone}) existe déjà.")

        serializer.save(agent=agent)

        log_activity(
            agent=agent,
            action="PUCE_ADDED",
            description=f"Nouvelle puce ajoutée: {operator} {phone}",
            level="INFO",
            ip_address=self.request.META.get('REMOTE_ADDR')
        )

    @action(detail=True, methods=['post'], permission_classes=[IsAdminUser])
    def topup(self, request, pk=None):
        """Admin: Recharger le solde d'une puce."""
        puce = self.get_object()
        amount = request.data.get('amount')

        if not amount:
            return Response({'error': 'Montant requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            amount = Decimal(str(amount))
            if amount <= 0:
                raise ValueError("Le montant doit être positif")
        except (Decimal.InvalidOperation, ValueError):
            return Response({'error': 'Montant invalide'}, status=status.HTTP_400_BAD_REQUEST)

        puce.balance += amount
        puce.save()

        log_activity(
            action="PUCE_TOPUP",
            description=f"Solde rechargé: +{amount} FCFA sur {puce.operator} ({puce.phone_number})",
            level="SUCCESS",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        return Response({
            'message': f'Solde rechargé: {amount} FCFA',
            'new_balance': puce.balance
        })


class TransactionViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """
    ViewSet pour les transactions.

    GET /api/transactions/              - Liste des transactions
    GET /api/transactions/{id}/          - Détail d'une transaction
    POST /api/transactions/deposit/      - Effectuer un dépôt
    POST /api/transactions/withdraw/     - Effectuer un retrait
    POST /api/transactions/conversion/   - Conversion entre puces
    POST /api/transactions/webhook/      - Webhook CinetPay (public)
    """
    permission_classes = [IsAuthenticated]
    serializer_class = TransactionSerializer
    pagination_class = StandardResultsSetPagination
    throttle_classes = [TransactionRateThrottle]

    def get_queryset(self):
        agent = getattr(self.request.user, 'agent_profile', None)
        if agent:
            return Transaction.objects.filter(agent=agent).order_by('-created_at')
        return Transaction.objects.none()

    def retrieve(self, request, *args, **kwargs):
        """Récupérer une transaction - avec vérification d'accès."""
        instance = self.get_object()

        # Sécurité: vérifier que l'agent owns la transaction
        agent = getattr(request.user, 'agent_profile', None)
        if agent and instance.agent != agent:
            log_activity(
                agent=agent,
                action="UNAUTHORIZED_TX_ACCESS",
                description=f"Tentative d'accès non autorisé à la transaction {instance.id}",
                level="ERROR",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Transaction introuvable'},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def deposit(self, request):
        """
        Effectuer un dépôtcompensé.

        POST /api/transactions/deposit/
        {
            "amount": 10000,
            "target_operator": "ORANGE",
            "target_phone_number": "621234567"
        }
        """
        serializer = DepositSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        agent = request.user.agent_profile

        # Vérifier si l'agent n'est pas suspendu
        if agent.is_suspended:
            log_activity(
                agent=agent,
                action="TX_DEPOSIT_REFUSED",
                description="Tentative de dépôt refusée: agent suspendu",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Votre compte est suspendu. Contactez le support.'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Plafonds KYC (lot C2) : remplace le blocage dur IsApprovedAgent par
        # des limites par palier (par operation / jour / mois) calculees serveur.
        ok_limit, limit_msg = LimitsEngine.check(agent, serializer.validated_data['amount'])
        if not ok_limit:
            log_activity(
                agent=agent,
                action="TX_LIMIT_EXCEEDED",
                description=f"Operation refusee (plafond KYC): {limit_msg}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR'),
            )
            return Response({'error': limit_msg}, status=status.HTTP_403_FORBIDDEN)

        # Si l'agent a configuré un PIN, exiger un pin_token valide
        if agent.pin_code:
            pin_token = request.data.get('pin_token') or request.headers.get('X-PIN-TOKEN')
            if not pin_token:
                return Response({'error': 'PIN verification required.'}, status=status.HTTP_401_UNAUTHORIZED)
            from django.core import signing
            from django.core.signing import BadSignature, SignatureExpired
            try:
                payload = signing.loads(pin_token, salt='pin-token', max_age=300)
                if payload.get('agent_id') != str(agent.id):
                    return Response({'error': 'Invalid PIN token.'}, status=status.HTTP_401_UNAUTHORIZED)
            except SignatureExpired:
                return Response({'error': 'PIN token expired.'}, status=status.HTTP_401_UNAUTHORIZED)
            except BadSignature:
                return Response({'error': 'Invalid PIN token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            tx = CompensationEngine.create_compensated_transaction(
                agent=agent,
                tx_type='DEPOT',
                amount=serializer.validated_data['amount'],
                target_operator=serializer.validated_data['target_operator'],
                target_phone_number=serializer.validated_data['target_phone_number']
            )

            log_activity(
                agent=agent,
                action="TX_DEPOT_INITIATED",
                description=f"Dépôt de {tx.amount} FCFA vers {tx.target_phone_number} initiated.",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            return Response({
                'message': 'Dépôt initié avec succès',
                'transaction_id': str(tx.id),
                'amount': str(tx.amount),
                'commission_sic': str(tx.commission_sic),
                'agent_benefit': str(tx.agent_benefit),
                'status': tx.status,
                'created_at': tx.created_at.isoformat()
            }, status=status.HTTP_201_CREATED)

        except ValueError as e:
            log_activity(
                agent=agent,
                action="TX_DEPOT_FAILED",
                description=f"Échec création dépôt: {str(e)}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            logger.exception(f"Erreur inattendue lors du dépôt: {e}")
            log_activity(
                agent=agent,
                action="TX_DEPOT_ERROR",
                description=f"Erreur technique: {str(e)}",
                level="ERROR",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Une erreur technique est survenue. Veuillez réessayer.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def withdraw(self, request):
        """
        Effectuer un retrait.

        POST /api/transactions/withdraw/
        {
            "amount": 10000,
            "target_operator": "ORANGE",
            "target_phone_number": "621234567"
        }
        """
        serializer = WithdrawSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        agent = request.user.agent_profile

        # Vérifier si l'agent n'est pas suspendu
        if agent.is_suspended:
            log_activity(
                agent=agent,
                action="TX_WITHDRAW_REFUSED",
                description="Tentative de retrait refusée: agent suspendu",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Votre compte est suspendu. Contactez le support.'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Plafonds KYC (lot C2) : remplace le blocage dur IsApprovedAgent par
        # des limites par palier (par operation / jour / mois) calculees serveur.
        ok_limit, limit_msg = LimitsEngine.check(agent, serializer.validated_data['amount'])
        if not ok_limit:
            log_activity(
                agent=agent,
                action="TX_LIMIT_EXCEEDED",
                description=f"Operation refusee (plafond KYC): {limit_msg}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR'),
            )
            return Response({'error': limit_msg}, status=status.HTTP_403_FORBIDDEN)

        # Si l'agent a configuré un PIN, exiger un pin_token valide
        if agent.pin_code:
            pin_token = request.data.get('pin_token') or request.headers.get('X-PIN-TOKEN')
            if not pin_token:
                return Response({'error': 'PIN verification required.'}, status=status.HTTP_401_UNAUTHORIZED)
            from django.core import signing
            from django.core.signing import BadSignature, SignatureExpired
            try:
                payload = signing.loads(pin_token, salt='pin-token', max_age=300)
                if payload.get('agent_id') != str(agent.id):
                    return Response({'error': 'Invalid PIN token.'}, status=status.HTTP_401_UNAUTHORIZED)
            except SignatureExpired:
                return Response({'error': 'PIN token expired.'}, status=status.HTTP_401_UNAUTHORIZED)
            except BadSignature:
                return Response({'error': 'Invalid PIN token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            tx = CompensationEngine.create_withdrawal_transaction(
                agent=agent,
                amount=serializer.validated_data['amount'],
                target_operator=serializer.validated_data['target_operator'],
                target_phone_number=serializer.validated_data['target_phone_number']
            )

            # Pour le retrait, l'agent encaisse le cash et valide la transaction
            # Le webhook sera appelé par CinetPay pour confirmer le paiement électronique
            # En mode simulacre, on valide immédiatement
            with transaction.atomic():
                tx.status = 'COMPLETED'
                tx.save()

                # Log de la commission de l'agent
                log_activity(
                    agent=agent,
                    action="TX_WITHDRAW_COMPLETED",
                    description=f"Retrait de {tx.amount} FCFA complété. Commission: {tx.agent_benefit} FCFA",
                    level="SUCCESS",
                    ip_address=request.META.get('REMOTE_ADDR')
                )

            return Response({
                'message': 'Retrait complété avec succès',
                'transaction_id': str(tx.id),
                'amount': str(tx.amount),
                'commission_sic': str(tx.commission_sic),
                'agent_benefit': str(tx.agent_benefit),
                'status': tx.status,
                'created_at': tx.created_at.isoformat()
            }, status=status.HTTP_201_CREATED)

        except ValueError as e:
            log_activity(
                agent=agent,
                action="TX_WITHDRAW_FAILED",
                description=f"Échec création retrait: {str(e)}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            logger.exception(f"Erreur inattendue lors du retrait: {e}")
            log_activity(
                agent=agent,
                action="TX_WITHDRAW_ERROR",
                description=f"Erreur technique: {str(e)}",
                level="ERROR",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Une erreur technique est survenue. Veuillez réessayer.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def conversion(self, request):
        """
        Effectuer une conversion entre puces.

        POST /api/transactions/conversion/
        {
            "amount": 5000,
            "source_puce_id": "uuid-source",
            "target_puce_id": "uuid-target"
        }
        """
        serializer = ConversionSerializer(data=request.data, context={'request': request})
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        agent = request.user.agent_profile

        if agent.is_suspended:
            return Response(
                {'error': 'Votre compte est suspendu.'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Plafonds KYC (lot C2) : remplace le blocage dur IsApprovedAgent par
        # des limites par palier (par operation / jour / mois) calculees serveur.
        ok_limit, limit_msg = LimitsEngine.check(agent, serializer.validated_data['amount'])
        if not ok_limit:
            log_activity(
                agent=agent,
                action="TX_LIMIT_EXCEEDED",
                description=f"Operation refusee (plafond KYC): {limit_msg}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR'),
            )
            return Response({'error': limit_msg}, status=status.HTTP_403_FORBIDDEN)

        # Si l'agent a configuré un PIN, exiger un pin_token valide
        if agent.pin_code:
            pin_token = request.data.get('pin_token') or request.headers.get('X-PIN-TOKEN')
            if not pin_token:
                return Response({'error': 'PIN verification required.'}, status=status.HTTP_401_UNAUTHORIZED)
            from django.core import signing
            from django.core.signing import BadSignature, SignatureExpired
            try:
                payload = signing.loads(pin_token, salt='pin-token', max_age=300)
                if payload.get('agent_id') != str(agent.id):
                    return Response({'error': 'Invalid PIN token.'}, status=status.HTTP_401_UNAUTHORIZED)
            except SignatureExpired:
                return Response({'error': 'PIN token expired.'}, status=status.HTTP_401_UNAUTHORIZED)
            except BadSignature:
                return Response({'error': 'Invalid PIN token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            source_puce = Puce.objects.get(
                id=serializer.validated_data['source_puce_id'],
                agent=agent
            )
            target_puce = Puce.objects.get(
                id=serializer.validated_data['target_puce_id'],
                agent=agent
            )
        except Puce.DoesNotExist:
            return Response(
                {'error': 'Puce invalide ou n\'appartenant pas à votre compte'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            tx = CompensationEngine.create_swap_transaction(
                agent=agent,
                amount=serializer.validated_data['amount'],
                source_puce=source_puce,
                target_puce=target_puce
            )

            # IMPORTANT: La transaction est créée avec le statut PENDING par le CompensationEngine.
            # Le véritable statut final sera défini par le webhook CinetPay.
            # En environnement de test/développement, vous devez appeler manuellement le webhook avec une signature valide.

            return Response({
                'message': 'Conversion initiée',
                'transaction_id': str(tx.id),
                'amount': str(tx.amount),
                'source_puce': f"{source_puce.operator} {source_puce.phone_number}",
                'target_puce': f"{target_puce.operator} {target_puce.phone_number}",
                'status': tx.status,
                'created_at': tx.created_at.isoformat()
            }, status=status.HTTP_201_CREATED)

        except ValueError as e:
            log_activity(
                agent=agent,
                action="TX_CONVERSION_FAILED",
                description=f"Échec conversion: {str(e)}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def webhook(self, request):
        """
        Webhook CinetPay pour confirmer les paiements.

        POST /api/transactions/webhook/
        Headers: x-token: signature HMAC
        Body: {
            "cpm_trans_id": "transaction_id",
            "cpm_site_id": "site_id",
            "cpm_amount": "10000",
            "cpm_currency": "XOF",
            "cpm_payment_date": "2024-01-01 12:00:00",
            "cpm_payment_status": "ACCEPTED"
        }
        """
        # Vérification de la signature HMAC
        x_token = request.headers.get('x-token')
        if not x_token:
            logger.warning("Webhook: Signature manquante")
            return Response(
                {'error': 'Missing signature'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        ref = request.data.get('cpm_trans_id') or request.data.get('cinetpay_ref')
        site_id = request.data.get('cpm_site_id', '')
        # Prefer explicit webhook secret name for clarity
        secret_key = None
        if isinstance(settings.CINETPAY_CONFIG, dict):
            secret_key = settings.CINETPAY_CONFIG.get('SECRET_KEY')
        # Backward compatibility: allow CINETPAY_WEBHOOK_SECRET env
        if not secret_key:
            secret_key = getattr(settings, 'CINETPAY_WEBHOOK_SECRET', None)

        if not ref:
            logger.warning("Webhook: Référence manquante")
            return Response(
                {'error': 'Missing ref'},
                status=status.HTTP_400_BAD_REQUEST
            )
        # Vérification de la signature HMAC - Exiger la clé MÊME en développement pour éviter le contournement
        if not secret_key:
            logger.error("Webhook: secret key not configured for CinetPay webhooks")
            return Response(
                {'error': 'Webhook secret not configured'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        expected_token = hmac.new(
            secret_key.encode('utf-8'),
            (site_id + str(ref)).encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(x_token, expected_token):
            logger.warning(f"Webhook: Signature invalide pour {ref}")
            log_activity(
                action="WEBHOOK_INVALID_SIGNATURE",
                description=f"Tentative de webhook avec signature invalide: {ref[:20]}...",
                level="ERROR"
            )
            return Response(
                {'error': 'Invalid signature'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Traiter le webhook via le moteur de compensation
        payment_status = request.data.get('cpm_payment_status', '')
        new_status = 'SUCCESS' if payment_status in ('ACCEPTED', 'SUCCESS') else 'FAILED'

        tx, success = CompensationEngine.process_webhook(ref, new_status, request.data)

        if tx is None:
            return Response(
                {'error': 'Transaction not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        logger.info(f"Webhook: Transaction {tx.id} mise à jour vers {new_status}")

        return Response({'success': success, 'transaction_id': str(tx.id)})


class CommissionInfoView(generics.GenericAPIView):
    """
    Vue pour récupérer les informations de commission.

    GET /api/commissions/
    """
    permission_classes = [AllowAny]
    throttle_classes = []

    def get(self, request):
        """Retourne les taux de commission actuels."""
        tx_type = request.query_params.get('type', '').upper()

        if tx_type and tx_type in settings.COMMISSION_RATES:
            r = CommissionCalculator.get_rate(tx_type)
            return Response({
                'type': tx_type,
                'sic_rate': float(r['sic_rate'] * 100),
                'agent_rate': float(r['agent_rate'] * 100),
                'min_amount': settings.MIN_TRANSACTION_AMOUNT,
                'max_amount': settings.MAX_TRANSACTION_AMOUNT
            })

        # Retourner tous les taux
        rates = {}
        for t in ['DEPOT', 'RETRAIT', 'TRANSFERT', 'SWAP']:
            r = CommissionCalculator.get_rate(t)
            rates[t] = {
                'sic_rate': float(r['sic_rate'] * 100),
                'agent_rate': float(r['agent_rate'] * 100),
            }
        return Response({
            'commissions': rates,
            'min_amount': settings.MIN_TRANSACTION_AMOUNT,
            'max_amount': settings.MAX_TRANSACTION_AMOUNT
        })


class HealthCheckView(generics.GenericAPIView):
    """
    Point de terminaison de santé de l'API.

    GET /api/health/
    """
    permission_classes = [AllowAny]
    throttle_classes = []

    def get(self, request):
        return Response({
            'status': 'healthy',
            'timestamp': timezone.now().isoformat(),
            'version': '1.0.0'
        })


# =============================================================================
# AUTHENTIFICATION AVANCÉE - Logout, PIN, Biométrie
# =============================================================================

class CustomTokenObtainPairView(generics.GenericAPIView):
    """
    Login avec JWT custom (ajoute agent_id, kyc_status, etc. dans le token).

    POST /api/auth/login/
    {"username": "...", "password": "..."}
    """
    permission_classes = [AllowAny]
    throttle_classes = [LoginRateThrottle]
    throttle_scope = 'login'

    def post(self, request, *args, **kwargs):
        from .serializers import CustomTokenObtainPairSerializer
        serializer = CustomTokenObtainPairSerializer(data=request.data)
        if serializer.is_valid():
            return Response(serializer.validated_data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_401_UNAUTHORIZED)


class LogoutView(generics.GenericAPIView):
    """
    Logout - Blackliste le refresh token.

    POST /api/auth/logout/
    {"refresh": "eyJ..."}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from rest_framework_simplejwt.tokens import RefreshToken
        from rest_framework_simplejwt.exceptions import TokenError

        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response(
                {'error': 'Le token de rafraîchissement est requis.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            token = RefreshToken(refresh_token)
            token.blacklist()

            log_activity(
                user=request.user,
                action="LOGOUT",
                description=f"Déconnexion de {request.user.username}",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            return Response({'message': 'Déconnexion réussie.'}, status=status.HTTP_200_OK)

        except TokenError:
            return Response(
                {'error': 'Token invalide ou déjà expiré.'},
                status=status.HTTP_400_BAD_REQUEST
            )


class PinSetupView(generics.GenericAPIView):
    """
    Définir ou modifier le code PIN.

    POST /api/auth/pin/setup/
    {"password": "...", "pin": "1234", "pin_confirm": "1234"}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from .serializers import PinSetupSerializer

        serializer = PinSetupSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # Vérifier le mot de passe
        if not request.user.check_password(serializer.validated_data['password']):
            log_activity(
                user=request.user,
                action="PIN_SETUP_FAILED",
                description="Tentative de configuration PIN avec mot de passe incorrect.",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Mot de passe incorrect.'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Définir le PIN
        agent = getattr(request.user, 'agent_profile', None)
        if not agent:
            return Response({'error': 'Profil agent introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        agent.set_pin(serializer.validated_data['pin'])

        log_activity(
            agent=agent,
            action="PIN_CONFIGURED",
            description="Code PIN configuré avec succès.",
            level="SUCCESS",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        return Response({'message': 'Code PIN configuré avec succès.'}, status=status.HTTP_200_OK)


class PinVerifyView(generics.GenericAPIView):
    """
    Vérifier le code PIN (avant une action sensible).

    POST /api/auth/pin/verify/
    {"pin": "1234"}

    Retourne un token temporaire de validation (valide 5 min).
    """
    permission_classes = [IsAuthenticated]
    throttle_classes = [PinRateThrottle]
    throttle_scope = 'pin'

    def post(self, request):
        from .serializers import PinVerifySerializer
        import time

        serializer = PinVerifySerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        agent = getattr(request.user, 'agent_profile', None)
        if not agent:
            return Response({'error': 'Profil agent introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        if not agent.pin_code:
            return Response(
                {'error': 'Aucun code PIN configuré. Veuillez en définir un.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Vérifier si le compte est verrouillé
        if agent.pin_locked_until and agent.pin_locked_until > timezone.now():
            remaining = (agent.pin_locked_until - timezone.now()).seconds // 60
            return Response(
                {'error': f'Compte verrouillé. Réessayez dans {remaining + 1} minute(s).'},
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )

        # Vérifier le PIN
        if agent.check_pin(serializer.validated_data['pin']):
            # Succès - reset des tentatives
            agent.pin_attempts = 0
            agent.pin_locked_until = None
            agent.save()

            # Générer un token de validation temporaire (5 min)
            # Utiliser django signing pour émettre un token horodaté vérifiable côté serveur
            from django.core import signing
            payload = {
                'agent_id': str(agent.id),
            }
            # Token signé (utiliser un salt spécifique)
            pin_token = signing.dumps(payload, salt='pin-token')

            log_activity(
                agent=agent,
                action="PIN_VERIFIED",
                description="Code PIN vérifié avec succès.",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            return Response({
                'message': 'Code PIN vérifié.',
                'pin_token': pin_token,
                'expires_in': 300  # 5 minutes
            }, status=status.HTTP_200_OK)
        else:
            # Échec - incrémenter les tentatives
            agent.pin_attempts += 1

            if agent.pin_attempts >= 5:
                # Verrouiller pendant 15 minutes
                agent.pin_locked_until = timezone.now() + timedelta(minutes=15)
                agent.save()

                log_activity(
                    agent=agent,
                    action="PIN_LOCKED",
                    description=f"Compte verrouillé après {agent.pin_attempts} tentatives PIN échouées.",
                    level="ERROR",
                    ip_address=request.META.get('REMOTE_ADDR')
                )

                return Response(
                    {'error': 'Trop de tentatives. Compte verrouillé pendant 15 minutes.'},
                    status=status.HTTP_429_TOO_MANY_REQUESTS
                )

            agent.save()

            log_activity(
                agent=agent,
                action="PIN_FAILED",
                description=f"Tentative PIN échouée ({agent.pin_attempts}/5).",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            return Response(
                {'error': f'Code PIN incorrect. {5 - agent.pin_attempts} tentative(s) restante(s).'},
                status=status.HTTP_401_UNAUTHORIZED
            )


class BiometricRegisterView(generics.GenericAPIView):
    """
    Enregistrer un appareil pour l'authentification biométrique.

    POST /api/auth/biometric/register/
    {"device_id": "...", "device_name": "iPhone 15", "public_key": "..."}

    Requiert d'être authentifié (l'agent doit d'abord se connecter normalement).
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from .serializers import BiometricRegisterSerializer

        serializer = BiometricRegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        agent = getattr(request.user, 'agent_profile', None)
        if not agent:
            return Response({'error': 'Profil agent introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        device_id = serializer.validated_data['device_id']

        # Vérifier si le device existe déjà
        existing = BiometricDevice.objects.filter(device_id=device_id).first()
        if existing:
            if existing.agent != agent:
                return Response(
                    {'error': 'Cet appareil est déjà enregistré sur un autre compte.'},
                    status=status.HTTP_409_CONFLICT
                )
            # Mettre à jour la clé publique
            existing.public_key = serializer.validated_data['public_key']
            existing.device_name = serializer.validated_data.get('device_name', '')
            existing.is_active = True
            existing.save()

            log_activity(
                agent=agent,
                action="BIOMETRIC_UPDATED",
                description=f"Appareil biométrique mis à jour: {existing.device_name or device_id[:12]}",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            return Response({
                'message': 'Appareil biométrique mis à jour.',
                'device_id': device_id
            }, status=status.HTTP_200_OK)

        # Limiter à 3 appareils par agent
        if BiometricDevice.objects.filter(agent=agent, is_active=True).count() >= 3:
            return Response(
                {'error': 'Maximum 3 appareils biométriques autorisés.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Créer le device
        device = BiometricDevice.objects.create(
            agent=agent,
            device_id=device_id,
            device_name=serializer.validated_data.get('device_name', ''),
            public_key=serializer.validated_data['public_key'],
            is_active=True
        )

        log_activity(
            agent=agent,
            action="BIOMETRIC_REGISTERED",
            description=f"Nouvel appareil biométrique enregistré: {device.device_name or device_id[:12]}",
            level="SUCCESS",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        return Response({
            'message': 'Appareil biométrique enregistré avec succès.',
            'device_id': device_id
        }, status=status.HTTP_201_CREATED)


class BiometricLoginView(generics.GenericAPIView):
    """
    Authentification par empreinte digitale.

    POST /api/auth/biometric/login/
    {"device_id": "...", "signature": "...", "timestamp": 1717200000}

    Le mobile signe le timestamp avec la clé privée après scan d'empreinte.
    L'API vérifie la signature avec la clé publique enregistrée.
    """
    permission_classes = [AllowAny]
    throttle_classes = [LoginRateThrottle]
    throttle_scope = 'login'

    def post(self, request):
        from .serializers import BiometricLoginSerializer
        import hashlib
        import time

        serializer = BiometricLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        device_id = serializer.validated_data['device_id']
        signature = serializer.validated_data['signature']
        timestamp = serializer.validated_data['timestamp']

        # Anti-replay: le timestamp ne doit pas être trop vieux (5 min max)
        # Accepte timestamp en secondes ou millisecondes (client peut envoyer les deux)
        current_time = int(time.time())
        ts = int(timestamp)
        # If timestamp looks like milliseconds, convert to seconds
        if ts > 1_000_000_000_000:
            ts = ts // 1000

        if abs(current_time - ts) > 300:
            return Response(
                {'error': 'Signature expirée. Veuillez réessayer.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        # Trouver le device
        try:
            device = BiometricDevice.objects.select_related('agent', 'agent__user').get(
                device_id=device_id, is_active=True
            )
        except BiometricDevice.DoesNotExist:
            log_activity(
                action="BIOMETRIC_LOGIN_FAILED",
                description=f"Tentative de login biométrique avec device inconnu: {device_id[:20]}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response(
                {'error': 'Appareil non reconnu ou désactivé.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        agent = device.agent

        # Vérifier que l'agent n'est pas suspendu
        if agent.is_suspended:
            return Response(
                {'error': 'Votre compte est suspendu.'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Vérification de la signature
        # Supporte deux formats de clé publique envoyés lors de l'enregistrement:
        # 1) PEM (RSA/ECDSA) - chaîne commençant par '-----BEGIN'
        # 2) clé publique raw encodée en base64 pour Ed25519 (migration recommandée)
        import base64
        message = f"{device_id}:{ts}".encode()

        pub = (device.public_key or '').strip()
        verified = False

        # Try PEM (RSA/ECDSA) if provided
        if pub.startswith('-----BEGIN'):
            try:
                from cryptography.hazmat.primitives import hashes
                from cryptography.hazmat.primitives.asymmetric import padding
                from cryptography.hazmat.primitives import serialization

                public_key = serialization.load_pem_public_key(pub.encode())

                # Signature may be hex or base64
                sig_bytes = None
                try:
                    sig_bytes = bytes.fromhex(signature)
                except Exception:
                    try:
                        sig_bytes = base64.b64decode(signature)
                    except Exception:
                        sig_bytes = signature.encode()

                # Try RSA PKCS1v15 then generic verify
                try:
                    public_key.verify(
                        sig_bytes,
                        message,
                        padding.PKCS1v15(),
                        hashes.SHA256()
                    )
                    verified = True
                except Exception:
                    # Try generic verify (e.g., ECDSA)
                    try:
                        public_key.verify(sig_bytes, message, hashes.SHA256())
                        verified = True
                    except Exception:
                        verified = False
            except Exception as e:
                logger.debug(f"PEM verify failed: {e}")

        else:
            # Assume base64-encoded Ed25519 public key
            try:
                pub_bytes = base64.b64decode(pub)
                # Signature expected in base64
                try:
                    sig_bytes = base64.b64decode(signature)
                except Exception:
                    # fallback: hex
                    sig_bytes = bytes.fromhex(signature)

                from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

                Ed25519PublicKey.from_public_bytes(pub_bytes).verify(sig_bytes, message)
                verified = True
            except Exception as e:
                logger.debug(f"Ed25519 verify failed: {e}")

        if not verified:
            # Allow legacy MD5/HMAC only if explicitly enabled via settings flag
            allow_legacy = getattr(settings, 'ALLOW_LEGACY_BIOMETRIC', False)
            if allow_legacy:
                try:
                    # legacy MD5 over device_id:timestamp:public_key
                    expected_md5 = hashlib.md5(f"{device_id}:{timestamp}:{device.public_key}".encode()).hexdigest()
                    if hmac.compare_digest(signature, expected_md5):
                        verified = True
                except Exception:
                    pass

        if not verified:
            log_activity(
                agent=agent,
                action="BIOMETRIC_LOGIN_INVALID",
                description="Signature biométrique invalide.",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            return Response({'error': 'Signature invalide.'}, status=status.HTTP_401_UNAUTHORIZED)

        # Succès - Générer les tokens JWT
        from rest_framework_simplejwt.tokens import RefreshToken
        from .serializers import CustomTokenObtainPairSerializer

        refresh = CustomTokenObtainPairSerializer.get_token(agent.user)

        # Mettre à jour last_used
        device.last_used_at = timezone.now()
        device.save()

        log_activity(
            agent=agent,
            action="BIOMETRIC_LOGIN_SUCCESS",
            description=f"Connexion biométrique réussie via {device.device_name or device_id[:12]}",
            level="INFO",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        return Response({
            'message': 'Authentification biométrique réussie.',
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'agent_id': str(agent.id),
            'first_name': agent.first_name or '',
        }, status=status.HTTP_200_OK)


class BiometricDeviceListView(generics.GenericAPIView):
    """
    Lister et révoquer les appareils biométriques.

    GET /api/auth/biometric/devices/ — Liste des appareils
    DELETE /api/auth/biometric/devices/ — Révoquer un appareil
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        agent = getattr(request.user, 'agent_profile', None)
        if not agent:
            return Response({'error': 'Profil agent introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        devices = BiometricDevice.objects.filter(agent=agent).order_by('-created_at')
        data = [{
            'id': str(d.id),
            'device_id': d.device_id,
            'device_name': d.device_name,
            'is_active': d.is_active,
            'last_used_at': d.last_used_at.isoformat() if d.last_used_at else None,
            'created_at': d.created_at.isoformat()
        } for d in devices]

        return Response({'devices': data}, status=status.HTTP_200_OK)

    def delete(self, request):
        agent = getattr(request.user, 'agent_profile', None)
        if not agent:
            return Response({'error': 'Profil agent introuvable.'}, status=status.HTTP_404_NOT_FOUND)

        device_id = request.data.get('device_id')
        if not device_id:
            return Response({'error': 'device_id requis.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            device = BiometricDevice.objects.get(agent=agent, device_id=device_id)
            device.is_active = False
            device.save()

            log_activity(
                agent=agent,
                action="BIOMETRIC_REVOKED",
                description=f"Appareil biométrique révoqué: {device.device_name or device_id[:12]}",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )

            return Response({'message': 'Appareil révoqué.'}, status=status.HTTP_200_OK)

        except BiometricDevice.DoesNotExist:
            return Response({'error': 'Appareil introuvable.'}, status=status.HTTP_404_NOT_FOUND)