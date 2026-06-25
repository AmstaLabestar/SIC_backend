import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import Transaction, Puce, EmailOtp

logger = logging.getLogger('sic.transactions')


def _rollback_pending(tx):
    """Rembourse les fonds réservés d'une transaction PENDING et la passe FAILED.

    Suppose `tx` déjà verrouillé (select_for_update) et de statut PENDING. Modèle
    de réservation : les fonds sont débités à la création, donc tout détail
    encore engagé (PENDING/SUCCESS) est recrédité.
    """
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
                f"[ROLLBACK] {detail.amount_deducted} FCFA remboursés sur "
                f"puce {puce.id} ({puce.operator})"
            )


@shared_task
def check_transaction_timeout(transaction_id):
    """Expiration d'UNE transaction (planifiée à la création, eta = +timeout).

    Si la transaction est restée PENDING au-delà du délai, on rembourse les fonds
    réservés et on la marque FAILED (sous verrou, anti lost-update / double).
    """
    try:
        with transaction.atomic():
            tx = Transaction.objects.select_for_update().get(id=transaction_id)
            if tx.status != 'PENDING':
                return
            logger.info(f"[TIMEOUT] Transaction {tx.id} expirée — rollback des fonds réservés.")
            _rollback_pending(tx)
    except Transaction.DoesNotExist:
        pass


@shared_task
def reconcile_stale_transactions():
    """Filet de sécurité périodique (celery-beat) : rattrape les transactions
    restées PENDING au-delà du délai (ex. tâche `eta` perdue après redémarrage du
    worker, ou webhook manqué) en rollbackant les fonds réservés.

    NOTE CinetPay : quand le règlement réel sera branché, interroger d'abord
    `CinetPayClient.check_transaction()` pour confirmer le statut côté opérateur
    AVANT de rollbacker (ne jamais annuler un paiement réellement abouti). Sans
    règlement réel, le rollback local est correct.
    """
    margin = settings.TRANSACTION_TIMEOUT_MINUTES + 5
    cutoff = timezone.now() - timedelta(minutes=margin)
    stale_ids = list(
        Transaction.objects
        .filter(status='PENDING', created_at__lt=cutoff)
        .values_list('id', flat=True)
    )
    count = 0
    for tx_id in stale_ids:
        try:
            with transaction.atomic():
                tx = Transaction.objects.select_for_update().get(id=tx_id)
                if tx.status != 'PENDING':
                    continue
                _rollback_pending(tx)
                count += 1
        except Transaction.DoesNotExist:
            continue
    if count:
        logger.warning(f"[RECONCILE] {count} transaction(s) PENDING périmée(s) rollbackée(s)")
    return count


@shared_task
def cleanup_expired_otps():
    """Hygiène base : purge les codes OTP expirés depuis plus de 24h."""
    cutoff = timezone.now() - timedelta(hours=24)
    deleted, _ = EmailOtp.objects.filter(expires_at__lt=cutoff).delete()
    if deleted:
        logger.info(f"[CLEANUP] {deleted} OTP expiré(s) supprimé(s)")
    return deleted
