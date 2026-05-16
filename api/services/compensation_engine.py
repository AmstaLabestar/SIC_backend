from django.db import transaction
from django.utils import timezone
from datetime import timedelta
from core.models import Puce, Transaction, CompensationDetail
import uuid

class CompensationEngine:
    @staticmethod
    def calculate_plan(agent, amount_required):
        """
        Calcule le plan de compensation en déduisant en cascade depuis les puces actives de l'agent.
        Retourne une liste de dictionnaires {'puce': Puce, 'amount': Decimal} ou lève une exception.
        """
        puces = Puce.objects.filter(agent=agent, is_active=True).order_by('-balance')
        
        # Validation du solde global
        total_balance = sum(puce.balance for puce in puces)
        if total_balance < amount_required:
            raise ValueError("Solde global insuffisant pour couvrir cette opération.")

        plan = []
        remaining = amount_required
        
        for puce in puces:
            if remaining <= 0:
                break
                
            deduct_amount = min(puce.balance, remaining)
            if deduct_amount > 0:
                plan.append({
                    'puce': puce,
                    'amount': deduct_amount
                })
                remaining -= deduct_amount

        if remaining > 0:
            raise ValueError("Impossible de trouver une combinaison valide pour la compensation.")
            
        return plan

    @staticmethod
    @transaction.atomic
    def create_compensated_transaction(agent, tx_type, amount, target_operator, target_phone_number):
        """
        Crée une transaction et ses détails de compensation.
        """
        plan = CompensationEngine.calculate_plan(agent, amount)
        is_compensated = len(plan) > 1

        tx = Transaction.objects.create(
            agent=agent,
            type=tx_type,
            status='PENDING',
            amount=amount,
            target_operator=target_operator,
            target_phone_number=target_phone_number,
            is_compensated=is_compensated
        )

        for item in plan:
            # TODO: Implémenter le vrai appel à CinetPay Client ici
            ref = f"CPAY_{uuid.uuid4().hex[:8].upper()}"
            CompensationDetail.objects.create(
                transaction=tx,
                puce=item['puce'],
                amount_deducted=item['amount'],
                status='PENDING',
                cinetpay_ref=ref
            )
            # En environnement réel, déclencher CinetPay PayIn collection ici

        # Import à l'intérieur pour éviter les dépendances circulaires
        from core.tasks import check_transaction_timeout
        check_transaction_timeout.apply_async((tx.id,), eta=timezone.now() + timedelta(minutes=5))

        return tx
