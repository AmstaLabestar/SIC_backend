"""
Moteur de limites KYC par paliers (lot C2).

Remplace le blocage dur `IsApprovedAgent` : tout compte peut transiger, mais
dans des plafonds qui dependent de son palier KYC. Plafonds CUMULES (par
operation + journalier + mensuel) calcules cote serveur pour empecher le
fractionnement. Les seuils sont des valeurs de DEPART, a valider avec la
conformite / BCEAO ; surchargeables via settings.KYC_LIMITS.
"""
from decimal import Decimal

from django.conf import settings
from django.db.models import Sum
from django.utils import timezone

from core.models import Transaction

# Palier -> plafonds (FCFA). None = illimite.
_DEFAULT_LIMITS = {
    0: {'per_op': Decimal('200000'), 'daily': Decimal('500000'), 'monthly': Decimal('2000000')},
    1: {'per_op': Decimal('1000000'), 'daily': Decimal('3000000'), 'monthly': Decimal('15000000')},
    2: {'per_op': None, 'daily': None, 'monthly': None},
}

# Statuts comptant dans la consommation (on exclut les echecs).
_COUNTED_STATUSES = ('PENDING', 'COMPLETED')


def _limits_table():
    return getattr(settings, 'KYC_LIMITS', _DEFAULT_LIMITS)


def _fmt(amount):
    """123456 -> '123 456'."""
    return f'{int(amount):,}'.replace(',', ' ')


class LimitsEngine:
    @staticmethod
    def limits_for(agent):
        table = _limits_table()
        tier = getattr(agent, 'kyc_tier', 0) or 0
        return table.get(tier, table[0])

    @staticmethod
    def usage(agent):
        """Montants cumules deja transiges aujourd'hui et ce mois-ci."""
        now = timezone.now()
        start_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_month = start_day.replace(day=1)
        base = Transaction.objects.filter(
            agent=agent, status__in=_COUNTED_STATUSES
        )
        day = base.filter(created_at__gte=start_day).aggregate(
            s=Sum('amount'))['s'] or Decimal('0')
        month = base.filter(created_at__gte=start_month).aggregate(
            s=Sum('amount'))['s'] or Decimal('0')
        return {'day': day, 'month': month}

    @classmethod
    def check(cls, agent, amount):
        """Verifie qu'une operation de [amount] respecte les plafonds du palier.

        Retourne `(ok: bool, message: str | None)`. Message d'upgrade explicite
        en cas de depassement.
        """
        amount = Decimal(str(amount))
        limits = cls.limits_for(agent)

        per_op = limits['per_op']
        if per_op is not None and amount > per_op:
            return False, (
                f'Plafond par operation atteint ({_fmt(per_op)} FCFA). '
                'Verifiez votre compte (KYC) pour des montants plus eleves.'
            )

        usage = cls.usage(agent)
        daily = limits['daily']
        if daily is not None and usage['day'] + amount > daily:
            return False, (
                f'Plafond journalier atteint ({_fmt(daily)} FCFA). '
                'Verifiez votre compte (KYC) pour augmenter vos limites.'
            )

        monthly = limits['monthly']
        if monthly is not None and usage['month'] + amount > monthly:
            return False, (
                f'Plafond mensuel atteint ({_fmt(monthly)} FCFA). '
                'Verifiez votre compte (KYC) pour augmenter vos limites.'
            )

        return True, None

    @classmethod
    def summary(cls, agent):
        """Etat des limites pour l'app (affichage du reste disponible)."""
        limits = cls.limits_for(agent)
        usage = cls.usage(agent)

        def remaining(cap, used):
            return None if cap is None else max(Decimal('0'), cap - used)

        return {
            'tier': getattr(agent, 'kyc_tier', 0) or 0,
            'per_op': limits['per_op'],
            'daily_limit': limits['daily'],
            'monthly_limit': limits['monthly'],
            'used_today': usage['day'],
            'used_month': usage['month'],
            'remaining_today': remaining(limits['daily'], usage['day']),
            'remaining_month': remaining(limits['monthly'], usage['month']),
        }
