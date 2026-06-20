import logging

from celery import shared_task
from django.db import transaction

from .models import Transaction, Puce

logger = logging.getLogger('sic.transactions')


@shared_task
def check_transaction_timeout(transaction_id):
    """
    Vérifie si une transaction PENDING est restée bloquée au-delà du délai.
    Si oui, passe la transaction en FAILED et REMBOURSE les fonds réservés.

    Modèle de réservation : les fonds sont débités dès la création de la
    transaction. À l'expiration, tout détail encore engagé (PENDING ou SUCCESS)
    est donc recrédité sur sa puce, sous verrou (anti lost-update / double).
    """
    try:
        with transaction.atomic():
            tx = Transaction.objects.select_for_update().get(id=transaction_id)
            if tx.status != 'PENDING':
                return

            logger.info(f"[TIMEOUT] Transaction {tx.id} expirée — rollback des fonds réservés.")
            tx.status = 'FAILED'
            tx.save(update_fields=['status'])

            for detail in tx.compensation_details.select_for_update():
                if detail.status in ('PENDING', 'SUCCESS'):
                    puce = Puce.objects.select_for_update().get(id=detail.puce_id)
                    puce.balance += detail.amount_deducted
                    puce.save(update_fields=['balance', 'updated_at'])
                    detail.status = 'REFUNDED'
                    detail.save(update_fields=['status'])
                    logger.info(
                        f"[TIMEOUT] {detail.amount_deducted} FCFA remboursés sur "
                        f"puce {puce.id} ({puce.operator})"
                    )
    except Transaction.DoesNotExist:
        pass
