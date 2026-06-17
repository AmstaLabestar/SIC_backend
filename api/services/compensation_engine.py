"""
Moteur de compensation pour SIC - Gestion des commissions et déductions
"""
from django.db import transaction
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal, ROUND_HALF_UP
import uuid
import logging

from core.models import Puce, Transaction, CompensationDetail, Agent
from .cinetpay_client import CinetPayClient

logger = logging.getLogger('sic.transactions')


class CommissionCalculator:
    """
    Calculateur de commissions pour les transactions SIC.

    SIC prélève une **commission unique** par transaction (lot C4) :
    - commission_sic_rate: pourcentage prélevé par la plateforme SIC.

    L'agent ne gagne rien *via* SIC (sa marge vient des opérateurs) : il n'y a
    donc plus de part « agent_benefit ».

    Exemple: pour un dépôt de 10000 FCFA avec taux SIC=1% → commission_sic = 100 FCFA.
    """

    @staticmethod
    def get_rate(tx_type):
        """Récupère le taux de commission SIC pour un type de transaction."""
        rates = settings.COMMISSION_RATES.get(tx_type.upper(), {})
        return {
            'sic_rate': Decimal(str(rates.get('commission_sic_rate', 1.0))) / 100,
        }

    @classmethod
    def calculate(cls, amount, tx_type):
        """
        Calcule la commission SIC pour un montant et type de transaction.

        Returns:
            dict avec 'commission_sic', 'total_commission', 'net_amount'
        """
        amount = Decimal(str(amount))
        rates = cls.get_rate(tx_type)

        commission_sic = (amount * rates['sic_rate']).quantize(Decimal('1'), rounding=ROUND_HALF_UP)

        return {
            'commission_sic': commission_sic,
            'total_commission': commission_sic,
            'net_amount': amount,
        }

    @classmethod
    def calculate_from_net(cls, net_amount, tx_type):
        """
        Calcule la commission à partir du montant net désiré (inverse du calcul).

        Returns:
            dict avec les montants ajustés
        """
        net_amount = Decimal(str(net_amount))
        rates = cls.get_rate(tx_type)

        total_rate = rates['sic_rate']

        if total_rate >= Decimal('1'):
            raise ValueError("Les taux de commission ne peuvent pas être >= 100%")

        gross_amount = (net_amount / (Decimal('1') - total_rate)).quantize(Decimal('1'), rounding=ROUND_HALF_UP)
        commission_sic = (gross_amount * rates['sic_rate']).quantize(Decimal('1'), rounding=ROUND_HALF_UP)

        return {
            'gross_amount': gross_amount,
            'commission_sic': commission_sic,
            'net_amount': net_amount,
            'total_commission': commission_sic,
        }


class TransactionValidator:
    """
    Validateur pour les transactions SIC.
    """

    # Opérateurs supportés (Burkina Faso + Côte d'Ivoire)
    VALID_OPERATORS = ['ORANGE', 'MOOV', 'TELECEL', 'MTN']

    # Préfixes nationaux par pays / opérateur (numéro SANS indicatif).
    # Burkina Faso (+226) : 8 chiffres.   Côte d'Ivoire (+225) : 10 chiffres.
    # Telecel n'existe pas en Côte d'Ivoire ; MTN n'existe pas au Burkina.
    BF_PREFIXES = {
        'ORANGE': ['04', '05', '06', '07', '44', '54', '55', '56', '57',
                   '64', '65', '66', '67', '74', '75', '76', '77'],
        'MOOV': ['01', '02', '03', '50', '51', '52', '53',
                 '60', '61', '62', '63', '70', '71', '72', '73'],
        'TELECEL': ['58', '59', '68', '69', '78', '79'],
    }
    CI_PREFIXES = {
        'ORANGE': ['07'],
        'MTN': ['05'],
        'MOOV': ['01'],
    }
    # Indicatifs pris en charge (les autres pays sont volontairement exclus).
    COUNTRY_CODES = ('+226', '226', '+225', '225')

    @classmethod
    def validate_amount(cls, amount):
        """Valide le montant de la transaction."""
        if amount < settings.MIN_TRANSACTION_AMOUNT:
            raise ValueError(f"Montant minimum: {settings.MIN_TRANSACTION_AMOUNT} FCFA")
        if amount > settings.MAX_TRANSACTION_AMOUNT:
            raise ValueError(f"Montant maximum: {settings.MAX_TRANSACTION_AMOUNT} FCFA")
        return True

    @classmethod
    def validate_operator(cls, operator):
        """Valide l'opérateur."""
        if operator.upper() not in cls.VALID_OPERATORS:
            raise ValueError(f"Opérateur invalide. Options: {', '.join(cls.VALID_OPERATORS)}")
        return True

    @classmethod
    def normalize_phone_number(cls, phone_number):
        """Nettoie le numéro et retire un éventuel indicatif (+226 / +225).

        Retourne le numéro national : 8 chiffres (Burkina) ou 10 (Côte d'Ivoire).
        """
        phone = (phone_number or '').strip()
        for ch in (' ', '-', '.', '(', ')'):
            phone = phone.replace(ch, '')
        for code in cls.COUNTRY_CODES:
            if phone.startswith(code):
                return phone[len(code):]
        if phone.startswith('+'):
            phone = phone[1:]
        return phone

    @classmethod
    def _patterns_for_operator(cls, operator):
        """Regex compilées (numéro national) valides pour cet opérateur."""
        import re
        operator = (operator or '').upper()
        patterns = []
        bf = cls.BF_PREFIXES.get(operator)
        if bf:
            patterns.append(re.compile(r'^(?:%s)\d{6}$' % '|'.join(bf)))  # 8 chiffres
        ci = cls.CI_PREFIXES.get(operator)
        if ci:
            patterns.append(re.compile(r'^(?:%s)\d{8}$' % '|'.join(ci)))  # 10 chiffres
        return patterns

    @classmethod
    def operator_for_number(cls, national):
        """Devine l'opérateur à partir du numéro national (ou None).

        Préfixes disjoints → au plus un opérateur possible.
        Burkina = 8 chiffres, Côte d'Ivoire = 10 chiffres.
        """
        national = (national or '').strip()
        for operator, prefixes in cls.BF_PREFIXES.items():
            if len(national) == 8 and any(national.startswith(p) for p in prefixes):
                return operator
        for operator, prefixes in cls.CI_PREFIXES.items():
            if len(national) == 10 and any(national.startswith(p) for p in prefixes):
                return operator
        return None

    @classmethod
    def validate_phone_number(cls, phone_number, operator=None):
        """Valide le numéro pour l'opérateur (Burkina +226 / Côte d'Ivoire +225).

        Lève ValueError si le format ne correspond à aucun préfixe valide.
        Retourne le numéro national normalisé.
        """
        national = cls.normalize_phone_number(phone_number)

        if operator:
            patterns = cls._patterns_for_operator(operator)
            if not patterns:
                raise ValueError(
                    f"Opérateur invalide: {operator}. "
                    f"Options: {', '.join(cls.VALID_OPERATORS)}"
                )
        else:
            # Sans opérateur précisé : accepter tout opérateur connu.
            patterns = []
            for op in cls.VALID_OPERATORS:
                patterns.extend(cls._patterns_for_operator(op))

        if not any(p.match(national) for p in patterns):
            op_label = (operator or '').upper() or 'cet opérateur'
            raise ValueError(
                f"Numéro invalide pour {op_label}. Format attendu : Burkina Faso "
                f"(+226, 8 chiffres) ou Côte d'Ivoire (+225, 10 chiffres) selon "
                f"les préfixes de l'opérateur."
            )

        return national

    @classmethod
    def validate_transaction(cls, tx_type, amount, target_operator, target_phone_number):
        """Valide une transaction complète."""
        cls.validate_amount(amount)
        cls.validate_operator(target_operator)
        cls.validate_phone_number(target_phone_number, target_operator)
        return True


class CompensationEngine:
    """
    Moteur de compensation pour SIC.

    Responsable de:
    - Calculer le plan de compensation (déduction en cascade sur les puces)
    - Créer les transactions avec leurs détails de compensation
    - Gérer leswebhooks CinetPay
    - Gérer les rollbacks en cas d'erreur
    """

    @staticmethod
    def calculate_plan(agent, amount_required):
        """
        Calcule le plan de compensation en déduisant en cascade depuis les puces actives de l'agent.

        Args:
            agent: Agent - L'agent qui effectue la transaction
            amount_required: Decimal - Montant à compenser

        Returns:
            list[dict] - Liste de {'puce': Puce, 'amount': Decimal}

        Raises:
            ValueError - Si le solde global est insuffisant ou erreur de calcul
        """
        # Valider l'agent
        if not isinstance(agent, Agent):
            raise ValueError("Agent invalide")

        # Valider le montant
        amount_required = Decimal(str(amount_required))
        if amount_required <= 0:
            raise ValueError("Le montant doit être supérieur à 0")

        # Récupérer les puces actives triées par solde décroissant
        puces = Puce.objects.filter(agent=agent, is_active=True).order_by('-balance')

        # Calcul du solde global
        total_balance = sum(puce.balance for puce in puces)
        if total_balance < amount_required:
            logger.warning(
                f"CompensationEngine: Solde insuffisant pour agent {agent.id}. "
                f"Requis: {amount_required}, Disponible: {total_balance}"
            )
            raise ValueError(
                f"Solde global insuffisant. Disponible: {total_balance} FCFA, "
                f"Requis: {amount_required} FCFA"
            )

        # Construction du plan de compensation
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
            raise ValueError("Impossible de calculer le plan de compensation.")

        logger.info(
            f"CompensationEngine: Plan créé pour agent {agent.id}, "
            f"{len(plan)} puce(s), montant {amount_required} FCFA"
        )

        return plan

    @staticmethod
    @transaction.atomic
    def create_compensated_transaction(
        agent,
        tx_type,
        amount,
        target_operator,
        target_phone_number,
        validate=True
    ):
        """
        Crée une transaction compensée et ses détails de compensation.

        Args:
            agent: Agent - L'agent effectuant la transaction
            tx_type: str - Type (DEPOT, RETRAIT, TRANSFERT, SWAP)
            amount: Decimal - Montant de la transaction
            target_operator: str - Opérateur cible
            target_phone_number: str - Numéro cible
            validate: bool - Si True, valide la transaction

        Returns:
            Transaction - La transaction créée
        """
        # Validation optionnelle
        if validate:
            TransactionValidator.validate_transaction(
                tx_type, amount, target_operator, target_phone_number
            )

        amount = Decimal(str(amount))

        # Calcul des commissions
        commissions = CommissionCalculator.calculate(amount, tx_type)

        # Calcul du plan de compensation
        plan = CompensationEngine.calculate_plan(agent, amount)
        is_compensated = len(plan) > 1

        # Création de la transaction
        tx = Transaction.objects.create(
            agent=agent,
            type=tx_type.upper(),
            status='PENDING',
            amount=amount,
            target_operator=target_operator.upper(),
            target_phone_number=target_phone_number,
            commission_sic=commissions['commission_sic'],
            is_compensated=is_compensated
        )

        logger.info(
            f"Transaction {tx.id} créée: {tx_type} {amount} FCFA → {target_operator} {target_phone_number}"
        )

        # Création des détails de compensation pour chaque puce du plan
        for item in plan:
            ref = f"CPAY_{uuid.uuid4().hex[:8].upper()}"

            CompensationDetail.objects.create(
                transaction=tx,
                puce=item['puce'],
                amount_deducted=item['amount'],
                status='PENDING',
                cinetpay_ref=ref
            )

            logger.debug(
                f"CompensationDetail créé: puce {item['puce'].id}, "
                f"montant {item['amount']} FCFA, ref {ref}"
            )

            # En environnement de production, déclencher le paiement CinetPay ici
            # CinetPayClient.initiate_payment(
            #     transaction_id=tx.id,
            #     amount=item['amount'],
            #     operator=item['puce'].operator,
            #     phone_number=item['puce'].phone_number,
            #     webhook_url=settings.CINETPAY_CONFIG['NOTIFY_URL']
            # )

        # Planification du timeout
        from core.tasks import check_transaction_timeout
        timeout_minutes = settings.TRANSACTION_TIMEOUT_MINUTES
        check_transaction_timeout.apply_async(
            (tx.id,),
            eta=timezone.now() + timedelta(minutes=timeout_minutes)
        )

        return tx

    @staticmethod
    @transaction.atomic
    def create_withdrawal_transaction(agent, amount, target_operator, target_phone_number):
        """
        Crée une transaction de retrait.

        Pour les retraits, l'agent encaisse du cash et transfère de la monnaie électronique.
        Il n'y a pas de compensation sur les puces de l'agent - c'est le mouvement inverse.

        Args:
            agent: Agent - L'agent effectuant le retrait
            amount: Decimal - Montant à retirer
            target_operator: str - Opérateur cible
            target_phone_number: str - Numéro cible

        Returns:
            Transaction - La transaction créée
        """
        amount = Decimal(str(amount))

        # Validation
        TransactionValidator.validate_transaction(
            'RETRAIT', amount, target_operator, target_phone_number
        )

        # Calcul des commissions pour retrait
        commissions = CommissionCalculator.calculate(amount, 'RETRAIT')

        tx = Transaction.objects.create(
            agent=agent,
            type='RETRAIT',
            status='PENDING',
            amount=amount,
            target_operator=target_operator.upper(),
            target_phone_number=target_phone_number,
            commission_sic=commissions['commission_sic'],
            is_compensated=False  # Pas de compensation - l'agent gère le cash
        )

        logger.info(
            f"Retrait {tx.id} créé: {amount} FCFA → {target_operator} {target_phone_number}"
        )

        # Planification du timeout
        from core.tasks import check_transaction_timeout
        check_transaction_timeout.apply_async(
            (tx.id,),
            eta=timezone.now() + timedelta(minutes=settings.TRANSACTION_TIMEOUT_MINUTES)
        )

        return tx

    @staticmethod
    @transaction.atomic
    def create_swap_transaction(agent, amount, source_puce, target_puce):
        """
        Crée une transaction de conversion/swap entre puces.

        Args:
            agent: Agent - L'agent effectuant la conversion
            amount: Decimal - Montant à convertir
            source_puce: Puce - Puce source (débit)
            target_puce: Puce - Puce cible (crédit)

        Returns:
            Transaction - La transaction créée
        """
        amount = Decimal(str(amount))

        # Validation du montant
        TransactionValidator.validate_amount(amount)

        # Vérifier que les puces appartiennent à l'agent
        if source_puce.agent != agent:
            raise ValueError("Puce source n'appartient pas à cet agent")
        if target_puce.agent != agent:
            raise ValueError("Puce cible n'appartient pas à cet agent")

        # Vérifier les soldes
        if source_puce.balance < amount:
            raise ValueError(
                f"Solde insuffisant sur la puce source. "
                f"Disponible: {source_puce.balance} FCFA, Requis: {amount} FCFA"
            )

        # Calcul des commissions
        commissions = CommissionCalculator.calculate(amount, 'SWAP')

        tx = Transaction.objects.create(
            agent=agent,
            type='SWAP',
            status='PENDING',
            amount=amount,
            target_operator=target_puce.operator,
            target_phone_number=str(target_puce.id),
            commission_sic=commissions['commission_sic'],
            is_compensated=False
        )

        # Créer le détail de compensation
        ref = f"CPAY_{uuid.uuid4().hex[:8].upper()}"
        CompensationDetail.objects.create(
            transaction=tx,
            puce=source_puce,
            amount_deducted=amount,
            status='PENDING',
            cinetpay_ref=ref
        )

        logger.info(
            f"Swap {tx.id} créé: {amount} FCFA de {source_puce.operator} → {target_puce.operator}"
        )

        # Planification du timeout
        from core.tasks import check_transaction_timeout
        check_transaction_timeout.apply_async(
            (tx.id,),
            eta=timezone.now() + timedelta(minutes=settings.TRANSACTION_TIMEOUT_MINUTES)
        )

        return tx

    @staticmethod
    @transaction.atomic
    def process_webhook(ref, new_status, cinetpay_data=None):
        """
        Traite un webhook de CinetPay.

        Args:
            ref: str - Référence de la transaction CinetPay
            new_status: str - Nouveau statut (SUCCESS, FAILED, REFUNDED)
            cinetpay_data: dict - Données additionnelles de CinetPay

        Returns:
            tuple(Transaction, bool) - (Transaction mise à jour, si succès)
        """
        try:
            detail = CompensationDetail.objects.select_related(
                'transaction', 'puce', 'transaction__agent'
            ).get(cinetpay_ref=ref)
        except CompensationDetail.DoesNotExist:
            logger.warning(f"Webhook: Référence introuvable: {ref}")
            return None, False

        # Ignorer si déjà traité
        if detail.status not in ('PENDING', 'SUCCESS'):
            logger.info(f"Webhook: Transaction déjà traitée: {detail.cinetpay_ref}")
            return detail.transaction, True

        tx = detail.transaction

        logger.info(
            f"Webhook: Traitement {ref} → {new_status} pour transaction {tx.id}"
        )

        if new_status == 'SUCCESS':
            return CompensationEngine._process_success(detail, tx)
        elif new_status == 'FAILED':
            return CompensationEngine._process_failed(detail, tx)
        elif new_status == 'REFUNDED':
            return CompensationEngine._process_refunded(detail, tx)
        else:
            logger.warning(f"Webhook: Statut inconnu: {new_status}")
            return tx, False

    @staticmethod
    @transaction.atomic
    def _process_success(detail, tx):
        """Traite le succès d'un détail de compensation.

        Idempotent (un rejeu du webhook ne re-débite pas) et protégé contre les
        mises à jour concurrentes (verrou de ligne sur le détail et la puce).
        """
        # Verrou + relecture du détail : si déjà traité, on s'arrête (idempotence).
        detail = CompensationDetail.objects.select_for_update().get(id=detail.id)
        if detail.status == 'SUCCESS':
            logger.info(f"Webhook rejoué ignoré pour le détail {detail.id} (déjà SUCCESS)")
            return tx, False

        detail.status = 'SUCCESS'
        detail.save()

        # Déduire le solde de la puce sous verrou (évite les lost-updates).
        puce = Puce.objects.select_for_update().get(id=detail.puce_id)
        puce.balance -= detail.amount_deducted
        puce.save()

        logger.info(
            f"Débit {detail.amount_deducted} FCFA sur puce {puce.id} ({puce.operator})"
        )

        # Vérifier si toute la transaction est complète
        all_details = tx.compensation_details.all()
        if all(d.status == 'SUCCESS' for d in all_details):
            tx.status = 'COMPLETED'
            tx.save()

            # Pour les SWAP, créditer la puce cible
            if tx.type == 'SWAP':
                try:
                    target_puce = Puce.objects.get(id=tx.target_phone_number)
                    target_puce.balance += tx.amount
                    target_puce.save()

                    logger.info(
                        f"Crédit {tx.amount} FCFA sur puce cible {target_puce.id}"
                    )
                except Puce.DoesNotExist:
                    logger.error(f"Impossible de trouver la puce cible pour le swap {tx.id}")

            logger.info(f"Transaction {tx.id} COMPLETED")
        else:
            logger.info(
                f"Transaction {tx.id} en attente ({all_details.filter(status='SUCCESS').count()}/{all_details.count()} détails)"
            )

        return tx, True

    @staticmethod
    @transaction.atomic
    def _process_failed(detail, tx):
        """Traite l'échec d'un détail de compensation."""
        detail.status = 'FAILED'
        detail.save()

        tx.status = 'FAILED'
        tx.save()

        logger.warning(f"Transaction {tx.id} FAILED")

        return tx, True

    @staticmethod
    @transaction.atomic
    def _process_refunded(detail, tx):
        """Traite le remboursement d'un détail de compensation."""
        # Si le détail était déjà succès, créditer la puce
        if detail.status == 'SUCCESS':
            puce = detail.puce
            puce.balance += detail.amount_deducted
            puce.save()

            logger.info(f"Remboursement {detail.amount_deducted} FCFA sur puce {puce.id}")

        detail.status = 'REFUNDED'
        detail.save()

        logger.info(f"Remboursement appliqué pour détail {detail.id}")

        return tx, True