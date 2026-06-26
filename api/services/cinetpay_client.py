"""
Client CinetPay - Integration avec l'API de paiement CinetPay

Documentation: https://docs.cinetpay.com/
"""
import time
import random
import string
import hashlib
import hmac
import logging
from typing import Optional, Dict, Any
from decimal import Decimal

import requests
from django.conf import settings

logger = logging.getLogger('sic.transactions')


class CinetPayException(Exception):
    """Exception personnalisée pour les erreurs CinetPay."""
    pass


class CinetPayClient:
    """
    Client pour l'API CinetPay v2.

    Gère:
    - La création de transactions de paiement
    - La vérification du statut des transactions
    - La gestion des webhooks
    - La signature HMAC des requêtes
    """

    def __init__(self):
        """Initialise le client avec les configurations."""
        cfg = settings.CINETPAY_CONFIG
        self.mode = (cfg.get('MODE') or 'mock').lower()
        self.api_key = cfg.get('API_KEY', '')
        self.site_id = cfg.get('SITE_ID', '')
        self.secret_key = cfg.get('SECRET_KEY', '')
        self.base_url = cfg.get('BASE_URL', 'https://api-checkout.cinetpay.com/v2')
        self.transfer_base_url = cfg.get('TRANSFER_BASE_URL', 'https://client.cinetpay.com/v1')
        self.transfer_password = cfg.get('TRANSFER_PASSWORD', '')
        self.notify_url = cfg.get('NOTIFY_URL', '')
        self.return_url = cfg.get('RETURN_URL', '')

        if self.mode != 'mock' and (not self.api_key or not self.site_id):
            # Sécurité : mode réel demandé mais credentials absents -> on reste
            # en simulation pour ne JAMAIS planter une opération métier.
            logger.error(
                "CinetPay: MODE=%s mais credentials manquants -> repli sur mock.",
                self.mode,
            )

    def use_mock(self):
        """True si aucun appel réseau réel ne doit être émis.

        Vrai en mode 'mock', ou dès qu'un credential essentiel manque (filet de
        sécurité, même si MODE=sandbox/live a été demandé par erreur).
        """
        return self.mode == 'mock' or not self.api_key or not self.site_id

    @property
    def BASE_URL(self):  # noqa: N802 — compat: ancien attribut de classe
        return self.base_url

    def _generate_transaction_id(self) -> str:
        """Génère un ID de transaction unique."""
        timestamp = int(time.time())
        random_part = ''.join(random.choices(string.ascii_uppercase + string.digits, k=9))
        return f"CP_{timestamp}_{random_part}"

    def _sign_request(self, data: Dict[str, Any]) -> str:
        """
        Génère la signature HMAC-SHA256 pour une requête.

        Args:
            data: Dictionary des données à signer

        Returns:
            str: Signature hexadécimale
        """
        # Construire la chaîne de signature
        # Format: key1=value1|key2=value2|...
        sign_data = '|'.join([f"{k}={v}" for k, v in sorted(data.items()) if v])

        signature = hmac.new(
            self.secret_key.encode('utf-8'),
            sign_data.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        return signature

    def _make_request(
        self,
        endpoint: str,
        method: str = 'POST',
        data: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Effectue une requête HTTP vers l'API CinetPay.

        Args:
            endpoint: Point de terminaison de l'API
            method: Méthode HTTP (GET, POST)
            data: Données JSON à envoyer

        Returns:
            dict: Réponse de l'API
        """
        url = f"{self.BASE_URL}/{endpoint}"
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        }

        try:
            if method == 'POST':
                response = requests.post(url, json=data, headers=headers, timeout=30)
            else:
                response = requests.get(url, params=data, headers=headers, timeout=30)

            response.raise_for_status()
            return response.json()

        except requests.exceptions.Timeout:
            logger.error(f"CinetPay: Timeout lors de la requête à {endpoint}")
            raise CinetPayException("Délai d'attente dépassé")

        except requests.exceptions.ConnectionError:
            logger.error(f"CinetPay: Erreur de connexion à {endpoint}")
            raise CinetPayException("Erreur de connexion")

        except requests.exceptions.HTTPError as e:
            logger.error(f"CinetPay: Erreur HTTP {e.response.status_code}: {e.response.text}")
            raise CinetPayException(f"Erreur HTTP: {e.response.status_code}")

        except Exception as e:
            logger.error(f"CinetPay: Erreur inattendue: {str(e)}")
            raise CinetPayException(f"Erreur inattendue: {str(e)}")

    def initiate_payment(
        self,
        transaction_id: str,
        amount: Decimal,
        operator: str,
        phone_number: str,
        description: str = "Paiement SIC",
        currency: str = 'XOF'
    ) -> Dict[str, Any]:
        """
        Initie un paiement via CinetPay.

        Args:
            transaction_id: ID de transaction interne (notre système)
            amount: Montant en FCFA
            operator: Opérateur mobile (ORANGE, MOOV, etc.)
            phone_number: Numéro de téléphone
            description: Description du paiement
            currency: Devise (par défaut XOF/FCFA)

        Returns:
            dict: {
                'success': bool,
                'cinetpay_trans_id': str,
                'payment_url': str (optionnel),
                'message': str
            }
        """
        # Mode simulation (mock, ou credentials absents)
        if self.use_mock():
            return self._mock_payment(
                transaction_id, amount, operator, phone_number, description
            )

        # Mapper les opérateurs CinetPay
        operator_mapping = {
            'ORANGE': 'ORANGE_MONEY',
            'MOOV': 'MOOV_MONEY',
            'TELECEL': 'TELECEL_MONEY',
            'CORIS': 'CORIS_MONEY',
        }

        cinetpay_operator = operator_mapping.get(operator.upper(), operator.upper())

        # Préparer les données
        data = {
            'apikey': self.api_key,
            'site_id': self.site_id,
            'transaction_id': transaction_id,
            'amount': float(amount),
            'currency': currency,
            'operator': cinetpay_operator,
            'phone_number': phone_number,
            'description': description[:100],  # Limite CinetPay
            'notify_url': self.notify_url,
            'return_url': self.return_url,
        }

        try:
            response = self._make_request('payment', method='POST', data=data)

            if response.get('code') == '200' or response.get('status') == '00':
                logger.info(f"CinetPay: Paiement initié {response.get('cinetpay_trans_id')}")
                return {
                    'success': True,
                    'cinetpay_trans_id': response.get('cinetpay_trans_id'),
                    'payment_url': response.get('payment_url'),
                    'message': response.get('message', 'Paiement initié')
                }
            else:
                logger.warning(
                    f"CinetPay: Paiement rejeté: {response.get('message', 'Erreur inconnue')}"
                )
                return {
                    'success': False,
                    'message': response.get('message', 'Erreur inconnue')
                }

        except CinetPayException as e:
            logger.error(f"CinetPay: Erreur lors de l'initiation: {str(e)}")
            return {
                'success': False,
                'message': str(e)
            }

    def check_transaction(self, cinetpay_trans_id: str) -> Dict[str, Any]:
        """
        Vérifie le statut d'une transaction CinetPay.

        Args:
            cinetpay_trans_id: ID de transaction CinetPay

        Returns:
            dict: {
                'status': str,
                'amount': Decimal,
                'message': str
            }
        """
        if self.use_mock():
            # Mode simulation
            return {
                'status': 'SUCCESS',
                'amount': Decimal('0'),
                'message': 'Transaction simulée'
            }

        data = {
            'apikey': self.api_key,
            'site_id': self.site_id,
            'transaction_id': cinetpay_trans_id,
        }

        try:
            response = self._make_request('status', method='POST', data=data)

            return {
                'status': response.get('status', 'PENDING'),
                'amount': Decimal(str(response.get('amount', 0))),
                'message': response.get('message', ''),
                'payment_date': response.get('payment_date'),
            }

        except CinetPayException as e:
            logger.error(f"CinetPay: Erreur lors de la vérification: {str(e)}")
            return {
                'status': 'ERROR',
                'message': str(e)
            }

    def refund(
        self,
        cinetpay_trans_id: str,
        amount: Optional[Decimal] = None,
        reason: str = "Remboursement SIC"
    ) -> Dict[str, Any]:
        """
        Effectue un remboursement via CinetPay.

        Args:
            cinetpay_trans_id: ID de transaction CinetPay
            amount: Montant à rembourser (optionnel, sinon total)
            reason: Raison du remboursement

        Returns:
            dict: {
                'success': bool,
                'refund_id': str,
                'message': str
            }
        """
        if self.use_mock():
            return {
                'success': True,
                'refund_id': f"REF_{random.randint(100000, 999999)}",
                'message': 'Remboursement simulé'
            }

        refund_data = {
            'apikey': self.api_key,
            'site_id': self.site_id,
            'transaction_id': cinetpay_trans_id,
            'reason': reason[:100],
        }

        if amount:
            refund_data['amount'] = float(amount)

        try:
            response = self._make_request('refund', method='POST', data=refund_data)

            if response.get('code') == '200' or response.get('status') == '00':
                return {
                    'success': True,
                    'refund_id': response.get('refund_id', cinetpay_trans_id),
                    'message': 'Remboursement effectué'
                }
            else:
                return {
                    'success': False,
                    'message': response.get('message', 'Erreur de remboursement')
                }

        except CinetPayException as e:
            logger.error(f"CinetPay: Erreur lors du remboursement: {str(e)}")
            return {
                'success': False,
                'message': str(e)
            }

    def _mock_payment(
        self,
        transaction_id: str,
        amount: Decimal,
        operator: str,
        phone_number: str,
        description: str
    ) -> Dict[str, Any]:
        """
        Mode simulation pour le développement.

        Returns:
            dict: Données de transaction simulée
        """
        logger.info(
            f"[CINETPAY MOCK] Transaction {transaction_id}: "
            f"{amount} FCFA → {operator} ({phone_number})"
        )

        # Simuler un délai réseau
        time.sleep(0.5)

        # Générer un ID de transaction fictif
        mock_id = f"CP_MOCK_{int(time.time())}_{random.randint(1000, 9999)}"

        return {
            'success': True,
            'cinetpay_trans_id': mock_id,
            'payment_url': None,
            'message': 'Transaction mockée avec succès (mode développement)',
            'mock': True
        }

    def verify_webhook_signature(
        self,
        token: str,
        reference: str,
        site_id: str
    ) -> bool:
        """
        Vérifie la signature HMAC d'un webhook CinetPay.

        Args:
            token: Token reçu dans le header x-token
            reference: Référence de la transaction
            site_id: ID du site CinetPay

        Returns:
            bool: True si la signature est valide
        """
        if not self.secret_key:
            logger.warning("CinetPay: Secret key non configuré, signature ignorée")
            return True

        expected_token = hmac.new(
            self.secret_key.encode('utf-8'),
            (site_id + str(reference)).encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        is_valid = hmac.compare_digest(token, expected_token)

        if not is_valid:
            logger.warning(f"CinetPay: Signature webhook invalide pour {reference}")

        return is_valid

    def get_payment_methods(self) -> Dict[str, Any]:
        """
        Récupère la liste des méthodes de paiement disponibles.

        Returns:
            dict: Méthodes de paiement supportées
        """
        return {
            'mobile_money': [
                {'code': 'ORANGE_MONEY', 'name': 'Orange Money', 'countries': ['SN', 'CI', 'ML', 'BF', 'NE', 'GN']},
                {'code': 'MOOV_MONEY', 'name': 'Moov Money', 'countries': ['TG', 'BJ', 'NE']},
                {'code': 'TELECEL_MONEY', 'name': 'Togocel Money', 'countries': ['TG']},
                {'code': 'CORIS_MONEY', 'name': 'Coris Money', 'countries': ['BF']},
                {'code': 'WAVE_MONEY', 'name': 'Wave', 'countries': ['SN']},
            ],
            'cards': [
                {'code': 'VISA', 'name': 'Visa'},
                {'code': 'MASTERCARD', 'name': 'Mastercard'},
            ]
        }


# Instance globale du client
cinetpay_client = CinetPayClient()