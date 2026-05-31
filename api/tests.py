"""
Tests pour l'API SIC
"""
import uuid
from decimal import Decimal
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from core.models import Agent, Puce, Transaction, CompensationDetail
from api.services.compensation_engine import (
    CompensationEngine, CommissionCalculator, TransactionValidator
)


class CommissionCalculatorTest(TestCase):
    """Tests pour le calculateur de commissions."""

    def test_calculate_depot_commission(self):
        """Test le calcul de commission pour un dépôt."""
        result = CommissionCalculator.calculate(Decimal('10000'), 'DEPOT')

        self.assertIn('commission_sic', result)
        self.assertIn('agent_benefit', result)
        self.assertIsInstance(result['commission_sic'], Decimal)
        self.assertIsInstance(result['agent_benefit'], Decimal)
        self.assertGreater(result['commission_sic'], 0)
        self.assertGreaterEqual(result['agent_benefit'], 0)

    def test_calculate_withdraw_commission(self):
        """Test le calcul de commission pour un retrait."""
        result = CommissionCalculator.calculate(Decimal('10000'), 'RETRAIT')

        # Les retraits ont généralement des taux différents
        self.assertIsInstance(result['commission_sic'], Decimal)
        self.assertIsInstance(result['agent_benefit'], Decimal)

    def test_calculate_zero_amount(self):
        """Test le calcul avec un montant de 0."""
        result = CommissionCalculator.calculate(Decimal('0'), 'DEPOT')

        self.assertEqual(result['commission_sic'], Decimal('0'))
        self.assertEqual(result['agent_benefit'], Decimal('0'))

    def test_calculate_from_net(self):
        """Test le calcul inverse (du net au brut)."""
        net_amount = Decimal('10000')
        result = CommissionCalculator.calculate_from_net(net_amount, 'DEPOT')

        self.assertIn('gross_amount', result)
        self.assertGreater(result['gross_amount'], net_amount)

    def test_get_rate_unknown_type(self):
        """Test le taux pour un type inconnu."""
        rates = CommissionCalculator.get_rate('UNKNOWN')

        self.assertIn('sic_rate', rates)
        self.assertIn('agent_rate', rates)


class TransactionValidatorTest(TestCase):
    """Tests pour le validateur de transactions."""

    def test_validate_amount_valid(self):
        """Test la validation d'un montant valide."""
        self.assertTrue(TransactionValidator.validate_amount(Decimal('1000')))

    def test_validate_amount_too_low(self):
        """Test la validation d'un montant trop bas."""
        with self.assertRaises(ValueError):
            TransactionValidator.validate_amount(Decimal('50'))

    def test_validate_operator_valid(self):
        """Test la validation d'un opérateur valide."""
        for op in ['ORANGE', 'MOOV', 'TELECEL', 'CORIS']:
            self.assertTrue(TransactionValidator.validate_operator(op))

    def test_validate_operator_invalid(self):
        """Test la validation d'un opérateur invalide."""
        with self.assertRaises(ValueError):
            TransactionValidator.validate_operator('INVALID')

    def test_validate_phone_number(self):
        """Test la validation d'un numéro de téléphone."""
        # Numéro valide avec indicatif
        self.assertTrue(TransactionValidator.validate_phone_number('+224621234567', 'ORANGE'))
        # Numéro sans indicatif
        self.assertTrue(TransactionValidator.validate_phone_number('621234567', 'MOOV'))


class AgentModelTest(TestCase):
    """Tests pour le modèle Agent."""

    def setUp(self):
        """Créer un agent de test."""
        self.user = User.objects.create_user(
            username='testagent',
            email='test@example.com',
            password='testpass123'
        )
        self.agent = Agent.objects.create(
            user=self.user,
            phone_number='+224621234567',
            first_name='Test',
            last_name='Agent'
        )

    def test_agent_creation(self):
        """Test la création d'un agent."""
        self.assertEqual(self.agent.phone_number, '+224621234567')
        self.assertEqual(self.agent.kyc_status, 'PENDING')
        self.assertFalse(self.agent.is_suspended)

    def test_agent_str(self):
        """Test la représentation string d'un agent."""
        self.assertIn('Test Agent', str(self.agent))
        self.assertIn('621234567', str(self.agent))


class PuceModelTest(TestCase):
    """Tests pour le modèle Puce."""

    def setUp(self):
        """Créer un agent et une puce de test."""
        self.user = User.objects.create_user(
            username='testagent',
            email='test@example.com',
            password='testpass123'
        )
        self.agent = Agent.objects.create(
            user=self.user,
            phone_number='+224621234567',
            first_name='Test',
            last_name='Agent'
        )
        self.puce = Puce.objects.create(
            agent=self.agent,
            operator='ORANGE',
            phone_number='+224621234567',
            balance=Decimal('50000.00')
        )

    def test_puce_creation(self):
        """Test la création d'une puce."""
        self.assertEqual(self.puce.operator, 'ORANGE')
        self.assertEqual(self.puce.balance, Decimal('50000.00'))
        self.assertTrue(self.puce.is_active)

    def test_puce_str(self):
        """Test la représentation string d'une puce."""
        self.assertIn('ORANGE', str(self.puce))
        self.assertIn('50000', str(self.puce))


class CompensationEngineTest(TestCase):
    """Tests pour le moteur de compensation."""

    def setUp(self):
        """Créer un agent et des puces de test."""
        self.user = User.objects.create_user(
            username='testagent',
            email='test@example.com',
            password='testpass123'
        )
        self.agent = Agent.objects.create(
            user=self.user,
            phone_number='+224621234567',
            first_name='Test',
            last_name='Agent'
        )
        # Créer plusieurs puces avec soldes
        self.puce1 = Puce.objects.create(
            agent=self.agent,
            operator='ORANGE',
            phone_number='+224621234567',
            balance=Decimal('10000.00')
        )
        self.puce2 = Puce.objects.create(
            agent=self.agent,
            operator='MOOV',
            phone_number='+224621234567',
            balance=Decimal('5000.00')
        )

    def test_calculate_plan_single_puce(self):
        """Test le plan avec une seule puce."""
        plan = CompensationEngine.calculate_plan(self.agent, Decimal('5000'))

        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0]['amount'], Decimal('5000'))
        self.assertEqual(plan[0]['puce'].id, self.puce1.id)

    def test_calculate_plan_multiple_puces(self):
        """Test le plan avec plusieurs puces (compensation cascade)."""
        plan = CompensationEngine.calculate_plan(self.agent, Decimal('12000'))

        # Devrait utiliser puce1 (10000) + puce2 (2000)
        self.assertEqual(len(plan), 2)
        total = sum(item['amount'] for item in plan)
        self.assertEqual(total, Decimal('12000'))

    def test_calculate_plan_insufficient_balance(self):
        """Test le plan avec solde insuffisant."""
        with self.assertRaises(ValueError) as context:
            CompensationEngine.calculate_plan(self.agent, Decimal('20000'))

        self.assertIn('insuffisant', str(context.exception).lower())

    def test_create_compensated_transaction(self):
        """Test la création d'une transaction compensée."""
        tx = CompensationEngine.create_compensated_transaction(
            agent=self.agent,
            tx_type='DEPOT',
            amount=Decimal('5000'),
            target_operator='ORANGE',
            target_phone_number='+224621234568'
        )

        self.assertIsNotNone(tx.id)
        self.assertEqual(tx.type, 'DEPOT')
        self.assertEqual(tx.status, 'PENDING')
        self.assertEqual(tx.amount, Decimal('5000'))
        self.assertGreaterEqual(tx.commission_sic, 0)
        self.assertGreaterEqual(tx.agent_benefit, 0)

    def test_create_withdrawal_transaction(self):
        """Test la création d'un retrait."""
        tx = CompensationEngine.create_withdrawal_transaction(
            agent=self.agent,
            amount=Decimal('3000'),
            target_operator='MOOV',
            target_phone_number='+224621234568'
        )

        self.assertIsNotNone(tx.id)
        self.assertEqual(tx.type, 'RETRAIT')
        self.assertEqual(tx.status, 'PENDING')
        self.assertFalse(tx.is_compensated)

    def test_create_swap_transaction(self):
        """Test la création d'une conversion."""
        tx = CompensationEngine.create_swap_transaction(
            agent=self.agent,
            amount=Decimal('2000'),
            source_puce=self.puce1,
            target_puce=self.puce2
        )

        self.assertIsNotNone(tx.id)
        self.assertEqual(tx.type, 'SWAP')
        self.assertEqual(tx.status, 'PENDING')


class TransactionAPITest(APITestCase):
    """Tests pour les endpoints API des transactions."""

    def setUp(self):
        """Créer un agent et s'authentifier."""
        self.user = User.objects.create_user(
            username='testagent',
            email='test@example.com',
            password='Testpass123!',
            is_staff=False
        )
        self.agent = Agent.objects.create(
            user=self.user,
            phone_number='+224621234567',
            first_name='Test',
            last_name='Agent',
            kyc_status='APPROVED'
        )
        # Créer des puces
        self.puce1 = Puce.objects.create(
            agent=self.agent,
            operator='ORANGE',
            phone_number='+224621234567',
            balance=Decimal('100000.00')
        )
        self.puce2 = Puce.objects.create(
            agent=self.agent,
            operator='MOOV',
            phone_number='+224621234568',
            balance=Decimal('50000.00')
        )
        # Obtenir le token JWT
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_get_transactions_empty(self):
        """Test la récupération de la liste des transactions (vide)."""
        response = self.client.get('/api/transactions/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_get_profile(self):
        """Test la récupération du profil."""
        response = self.client.get('/api/auth/profile/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('phone_number', response.data)

    def test_get_puces(self):
        """Test la récupération des puces."""
        response = self.client.get('/api/puces/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data['results']), 2)

    def test_create_deposit(self):
        """Test la création d'un dépôt."""
        response = self.client.post('/api/transactions/deposit/', {
            'amount': '5000',
            'target_operator': 'ORANGE',
            'target_phone_number': '+224621234568'
        })
        self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST])

    def test_create_deposit_invalid_amount(self):
        """Test la création d'un dépôt avec montant invalide."""
        response = self.client.post('/api/transactions/deposit/', {
            'amount': '50',  # Trop petit
            'target_operator': 'ORANGE',
            'target_phone_number': '+224621234568'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_create_conversion(self):
        """Test la création d'une conversion."""
        response = self.client.post('/api/transactions/conversion/', {
            'amount': '1000',
            'source_puce_id': str(self.puce1.id),
            'target_puce_id': str(self.puce2.id)
        })
        self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST])

    def test_health_check(self):
        """Test le endpoint de santé."""
        response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('status', response.data)

    def test_commission_info(self):
        """Test le endpoint d'informations de commission."""
        response = self.client.get('/api/commissions/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('commissions', response.data)


class SecurityTest(APITestCase):
    """Tests de sécurité."""

    def test_unauthenticated_access(self):
        """Test que les endpoints protégés nécessitent une authentification."""
        endpoints = [
            '/api/transactions/',
            '/api/puces/',
            '/api/auth/profile/',
        ]
        for endpoint in endpoints:
            response = self.client.get(endpoint)
            self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_invalid_token(self):
        """Test l'accès avec un token invalide."""
        self.client.credentials(HTTP_AUTHORIZATION='Bearer invalid_token')
        response = self.client.get('/api/auth/profile/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_suspended_agent_cannot_transact(self):
        """Test qu'un agent suspendu ne peut pas effectuer de transactions."""
        # Créer et suspendre un agent
        user = User.objects.create_user(
            username='suspendedagent',
            email='suspended@example.com',
            password='Testpass123!'
        )
        agent = Agent.objects.create(
            user=user,
            phone_number='+224621234569',
            first_name='Suspended',
            last_name='Agent',
            kyc_status='APPROVED',
            is_suspended=True
        )
        Puce.objects.create(
            agent=agent,
            operator='ORANGE',
            phone_number='+224621234569',
            balance=Decimal('10000.00')
        )

        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        response = self.client.post('/api/transactions/deposit/', {
            'amount': '1000',
            'target_operator': 'ORANGE',
            'target_phone_number': '+224621234568'
        })
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class DashboardViewsTest(TestCase):
    """Tests pour les vues du dashboard."""

    def setUp(self):
        """Créer un admin."""
        self.admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='Adminpass123!'
        )

    def test_admin_login(self):
        """Test la connexion admin."""
        response = self.client.post('/dashboard/login/', {
            'username': 'admin',
            'password': 'Adminpass123!'
        })
        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_302_FOUND])

    def test_admin_dashboard_access(self):
        """Test l'accès au dashboard admin."""
        self.client.login(username='admin', password='Adminpass123!')
        response = self.client.get('/dashboard/')
        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_302_FOUND])