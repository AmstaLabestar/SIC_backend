"""
Abstraction agrégateur de paiement (PaymentProvider) + point de bascule unique.

But : le moteur de compensation et le reste de l'app ne dépendent JAMAIS d'un
agrégateur concret (CinetPay aujourd'hui, HUB2 demain), mais de ce contrat
abstrait. Changer d'agrégateur = écrire une nouvelle implémentation de
`PaymentProvider` + changer le réglage `PAYMENT_PROVIDER` ; aucune réécriture du
moteur. C'est l'unique endroit qui « connaît » la liste des providers.

Périmètre du contrat = les opérations SORTANTES (vers l'agrégateur) :
- `initiate_payment` (encaissement / checkout),
- `payout` (décaissement / transfert),
- `check_transaction` (statut, pour la réconciliation),
- `refund` (remboursement),
- `use_mock` (mode simulation : aucun appel réseau).

⚠️ La vérification du webhook ENTRANT (signature HMAC) reste aujourd'hui dans la
vue `api/views.py::webhook` car elle est fortement spécifique au format CinetPay
(noms de champs `cpm_*`, allowlist IP). C'est le prochain seam à abstraire quand
le durcissement webhook (lot 4) sera finalisé.
"""
from abc import ABC, abstractmethod
from decimal import Decimal
from typing import Any, Dict, Optional

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured


class PaymentProvider(ABC):
    """Contrat minimal qu'un agrégateur de paiement doit fournir au système SIC.

    Chaque méthode renvoie un dict normalisé (mêmes clés quel que soit
    l'agrégateur) pour que les appelants restent agnostiques de l'implémentation.
    """

    @abstractmethod
    def use_mock(self) -> bool:
        """True si aucun appel réseau réel ne doit être émis (mode simulation)."""

    @abstractmethod
    def initiate_payment(
        self,
        transaction_id: str,
        amount: Decimal,
        operator: str,
        phone_number: str,
        description: str = "Paiement SIC",
        currency: str = "XOF",
    ) -> Dict[str, Any]:
        """Encaissement : tire l'argent depuis le wallet du client.

        Returns: {'success': bool, ...} (clés spécifiques au provider tolérées).
        """

    @abstractmethod
    def payout(
        self,
        transaction_id: str,
        amount: Decimal,
        operator: str,
        phone_number: str,
        name: str = "SIC",
        country_prefix: str = "226",
        currency: str = "XOF",
    ) -> Dict[str, Any]:
        """Décaissement : pousse l'argent vers le wallet d'un destinataire.

        Returns: {'success': bool, 'transfer_id': str|None, 'message': str}.
        """

    @abstractmethod
    def check_transaction(self, provider_trans_id: str) -> Dict[str, Any]:
        """Statut d'une transaction côté agrégateur (pour la réconciliation).

        Returns: {'status': str, 'amount': Decimal, 'message': str, ...}.
        """

    @abstractmethod
    def refund(
        self,
        provider_trans_id: str,
        amount: Optional[Decimal] = None,
        reason: str = "Remboursement SIC",
    ) -> Dict[str, Any]:
        """Remboursement total ou partiel.

        Returns: {'success': bool, 'refund_id': str, 'message': str}.
        """


def get_payment_provider() -> PaymentProvider:
    """Retourne l'agrégateur configuré (POINT DE BASCULE UNIQUE).

    Piloté par `settings.PAYMENT_PROVIDER` (défaut 'cinetpay'). Import paresseux
    des implémentations pour éviter les imports circulaires (les clients importent
    `PaymentProvider` depuis ce module).
    """
    name = (getattr(settings, "PAYMENT_PROVIDER", "cinetpay") or "cinetpay").lower()

    if name == "cinetpay":
        from .cinetpay_client import CinetPayClient
        return CinetPayClient()

    # Brancher HUB2 ici le jour venu :
    # if name == "hub2":
    #     from .hub2_client import Hub2Client
    #     return Hub2Client()

    raise ImproperlyConfigured(
        f"PAYMENT_PROVIDER inconnu: {name!r}. Valeurs supportées : 'cinetpay' "
        f"(et 'hub2' à venir)."
    )
