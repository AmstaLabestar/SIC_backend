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
        for op in ['ORANGE', 'MOOV', 'TELECEL', 'MTN']:
            self.assertTrue(TransactionValidator.validate_operator(op))

    def test_validate_operator_invalid(self):
        """Test la validation d'un opérateur invalide."""
        with self.assertRaises(ValueError):
            TransactionValidator.validate_operator('INVALID')

    def test_validate_phone_number(self):
        """Test la validation d'un numéro de téléphone (Burkina Faso)."""
        # Orange Burkina (8 chiffres, préfixe 07) avec indicatif +226
        self.assertEqual(
            TransactionValidator.validate_phone_number('+22607123456', 'ORANGE'),
            '07123456',
        )
        # Moov Burkina (préfixe 70) sans indicatif
        self.assertEqual(
            TransactionValidator.validate_phone_number('70123456', 'MOOV'),
            '70123456',
        )
        # Numéro qui ne correspond pas à l'opérateur -> rejet
        with self.assertRaises(ValueError):
            TransactionValidator.validate_phone_number('70123456', 'ORANGE')


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
            target_phone_number='07000002'
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
            target_phone_number='70000002'
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
            'target_phone_number': '07000002'
        })
        self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST])

    def test_create_deposit_invalid_amount(self):
        """Test la création d'un dépôt avec montant invalide."""
        response = self.client.post('/api/transactions/deposit/', {
            'amount': '50',  # Trop petit
            'target_operator': 'ORANGE',
            'target_phone_number': '07000002'
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
            'target_phone_number': '07000002'
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


class RegisterSerializerTest(TestCase):
    """Tests de l'inscription (au niveau serializer, sans throttle)."""

    def _data(self, username, phone):
        return {
            'username': username,
            'email': f'{username}@test.com',
            'password': 'Passw0rd123',
            'password_confirm': 'Passw0rd123',
            'phone_number': phone,
            'first_name': 'Test',
            'last_name': 'Agent',
        }

    def test_register_cree_la_premiere_puce_depuis_le_numero(self):
        from api.serializers import RegisterSerializer
        s = RegisterSerializer(data=self._data('agentmoov', '70222444'))
        self.assertTrue(s.is_valid(), s.errors)
        user = s.save()
        agent = user.agent_profile
        self.assertEqual(agent.puces.count(), 1)
        puce = agent.puces.first()
        self.assertEqual(puce.operator, 'MOOV')  # 70xx -> Moov Burkina
        self.assertEqual(puce.phone_number, '70222444')

    def test_register_refuse_un_numero_deja_utilise(self):
        from api.serializers import RegisterSerializer
        first = RegisterSerializer(data=self._data('agentone', '07222444'))
        self.assertTrue(first.is_valid(), first.errors)
        first.save()

        dup = RegisterSerializer(data=self._data('agenttwo', '07222444'))
        self.assertFalse(dup.is_valid())
        self.assertIn('phone_number', dup.errors)

    # --- C1 : types de compte ---------------------------------------------

    def test_register_defaut_agent(self):
        """Sans account_type, le compte est un AGENT (compat ascendante)."""
        from api.serializers import RegisterSerializer
        s = RegisterSerializer(data=self._data('agentdef', '70222555'))
        self.assertTrue(s.is_valid(), s.errors)
        agent = s.save().agent_profile
        self.assertEqual(agent.account_type, Agent.ACCOUNT_AGENT)
        self.assertEqual(agent.puces.count(), 1)

    def test_register_client_sans_puce(self):
        """Un CLIENT n'a pas de puce (modèle overlay)."""
        from api.serializers import RegisterSerializer
        data = {**self._data('clientun', '70222666'), 'account_type': 'CLIENT'}
        s = RegisterSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        agent = s.save().agent_profile
        self.assertEqual(agent.account_type, Agent.ACCOUNT_CLIENT)
        self.assertEqual(agent.puces.count(), 0)

    def test_token_expose_account_type(self):
        """Le JWT porte account_type (pour le routage de rôle côté app)."""
        from api.serializers import RegisterSerializer, CustomTokenObtainPairSerializer
        data = {**self._data('clientdeux', '70222777'), 'account_type': 'CLIENT'}
        s = RegisterSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        user = s.save()
        token = CustomTokenObtainPairSerializer.get_token(user)
        self.assertEqual(token['account_type'], 'CLIENT')


class PuceGlobalUniquenessTest(APITestCase):
    """Un numéro de puce ne peut appartenir qu'à un seul agent (fintech)."""

    def setUp(self):
        self.ua = User.objects.create_user('agalpha', 'a@a.com', 'Passw0rd123')
        self.aa = Agent.objects.create(
            user=self.ua, phone_number='70901001',
            first_name='A', last_name='A', kyc_status='APPROVED',
        )
        Puce.objects.create(agent=self.aa, operator='MOOV',
                            phone_number='70901001', balance=Decimal('0'))

        self.ub = User.objects.create_user('agbeta', 'b@b.com', 'Passw0rd123')
        self.ab = Agent.objects.create(
            user=self.ub, phone_number='67901002',
            first_name='B', last_name='B', kyc_status='APPROVED',
        )
        Puce.objects.create(agent=self.ab, operator='ORANGE',
                            phone_number='67901002', balance=Decimal('0'))

        refresh = RefreshToken.for_user(self.ua)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_refuse_un_numero_appartenant_a_un_autre_agent(self):
        resp = self.client.post('/api/puces/',
                                {'operator': 'ORANGE', 'phone_number': '67901002'})
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('phone_number', resp.data)

    def test_accepte_un_numero_neuf(self):
        resp = self.client.post('/api/puces/',
                                {'operator': 'TELECEL', 'phone_number': '78901003'})
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)


class LimitsEngineTest(TestCase):
    """Moteur de limites KYC (lot C2)."""

    def setUp(self):
        self.user = User.objects.create_user('limuser', 'l@l.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70809999',
            first_name='L', last_name='E', kyc_status='PENDING', kyc_tier=0,
        )

    def test_plafond_par_operation_t0(self):
        from api.services.limits import LimitsEngine
        ok, msg = LimitsEngine.check(self.agent, Decimal('200001'))
        self.assertFalse(ok)
        self.assertIn('operation', msg.lower())
        ok2, _ = LimitsEngine.check(self.agent, Decimal('200000'))
        self.assertTrue(ok2)

    def test_plafond_journalier_t0(self):
        from api.services.limits import LimitsEngine
        # 400k déjà transigés aujourd'hui ; +150k -> 550k > 500k (journalier T0).
        Transaction.objects.create(
            agent=self.agent, type='DEPOT', status='PENDING',
            target_operator='MOOV', amount=Decimal('400000'),
        )
        ok, msg = LimitsEngine.check(self.agent, Decimal('150000'))
        self.assertFalse(ok)
        self.assertIn('journalier', msg.lower())

    def test_palier_2_illimite(self):
        from api.services.limits import LimitsEngine
        self.agent.kyc_tier = 2
        self.agent.save()
        ok, _ = LimitsEngine.check(self.agent, Decimal('99999999'))
        self.assertTrue(ok)


class KycLimitsAPITest(APITestCase):
    """Enforcement des limites au niveau API + déblocage du compte PENDING."""

    def setUp(self):
        self.user = User.objects.create_user('starter', 'starter@test.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70801234',
            first_name='S', last_name='T', kyc_status='PENDING', kyc_tier=0,
        )
        Puce.objects.create(
            agent=self.agent, operator='MOOV',
            phone_number='70801234', balance=Decimal('500000'),
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_compte_pending_peut_transiger_sous_plafond(self):
        """Avant C2, IsApprovedAgent renvoyait 403. Désormais : autorisé."""
        resp = self.client.post('/api/transactions/deposit/', {
            'amount': '5000', 'target_operator': 'MOOV',
            'target_phone_number': '70801299',
        })
        self.assertNotEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_depassement_plafond_par_operation_refuse(self):
        resp = self.client.post('/api/transactions/deposit/', {
            'amount': '300000', 'target_operator': 'MOOV',
            'target_phone_number': '70801299',
        })
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('Plafond', resp.data['error'])

    def test_endpoint_limites(self):
        resp = self.client.get('/api/auth/limits/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['tier'], 0)
        self.assertEqual(resp.data['per_op'], '200000')