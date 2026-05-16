from celery import shared_task
from django.db import transaction
from .models import Transaction, CompensationDetail

@shared_task
def check_transaction_timeout(transaction_id):
    """
    Vérifie si une transaction PENDING est restée bloquée pendant 5 mins.
    Si oui, passe la transaction en FAILED et rembourse (REFUNDED) l'agent.
    """
    try:
        tx = Transaction.objects.get(id=transaction_id)
        if tx.status == 'PENDING':
            print(f"[CRON] La transaction {tx.id} a expiré. Déclenchement du Rollback.")
            
            with transaction.atomic():
                tx.status = 'FAILED'
                tx.save()
                
                details = tx.compensation_details.all()
                for detail in details:
                    if detail.status == 'SUCCESS':
                        # L'agent a validé ce paiement, on le rembourse
                        puce = detail.puce
                        puce.balance += detail.amount_deducted
                        puce.save()
                        
                        detail.status = 'REFUNDED'
                        detail.save()
                        print(f"   -> [ROLLBACK] {detail.amount_deducted} FCFA remboursés sur {puce.operator}")
                    elif detail.status == 'PENDING':
                        # Jamais validé
                        detail.status = 'FAILED'
                        detail.save()
                        
            print("[CRON] Rollback terminé avec succès.")
    except Transaction.DoesNotExist:
        pass
