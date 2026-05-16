import time
import random
import string
import logging

logger = logging.getLogger(__name__)

class CinetpayClient:
    @staticmethod
    def execute_transaction(tx_type, amount, operator, phone_number):
        """
        MOCK: Simulate a successful CinetPay transaction
        """
        logger.info(f"[CINETPAY MOCK] Executing {tx_type} of {amount} FCFA to {operator} ({phone_number})")
        
        # Simulate network delay
        time.sleep(1)
        
        tx_id = 'CP_' + ''.join(random.choices(string.ascii_uppercase + string.digits, k=9))
        
        return {
            'success': True,
            'transactionId': tx_id,
            'message': 'Transaction mockée avec succès',
            'fee': float(amount) * 0.01 # Mock 1% fee for CinetPay
        }
