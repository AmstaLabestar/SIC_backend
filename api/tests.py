"""
Tests pour l'API SIC
"""
import uuid
from decimal import Decimal
from unittest import mock
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
        self.assertNotIn('agent_benefit', result)  # supprimé (lot C4)
        self.assertIsInstance(result['commission_sic'], Decimal)
        self.assertGreater(result['commission_sic'], 0)

    def test_calculate_withdraw_commission(self):
        """Test le calcul de commission pour un retrait."""
        result = CommissionCalculator.calculate(Decimal('10000'), 'RETRAIT')

        # Les retraits ont généralement des taux différents
        self.assertIsInstance(result['commission_sic'], Decimal)

    def test_calculate_zero_amount(self):
        """Test le calcul avec un montant de 0."""
        result = CommissionCalculator.calculate(Decimal('0'), 'DEPOT')

        self.assertEqual(result['commission_sic'], Decimal('0'))

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
        # Créer plusieurs puces avec soldes (numéros distincts : Puce.phone_number
        # est unique depuis la migration 0007).
        self.puce1 = Puce.objects.create(
            agent=self.agent,
            operator='ORANGE',
            phone_number='+224620000001',
            balance=Decimal('10000.00')
        )
        self.puce2 = Puce.objects.create(
            agent=self.agent,
            operator='MOOV',
            phone_number='+224620000002',
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

    # NB : en mode eager (DEBUG), la task de timeout ignore l'eta et s'exécute
    # immédiatement, ce qui rembourserait la réservation. On neutralise donc sa
    # planification pour vérifier l'état réservé (en prod, eager est off).
    @mock.patch('core.tasks.check_transaction_timeout.apply_async')
    def test_create_compensated_transaction(self, _timeout):
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
        # Réservation immédiate des fonds : puce1 (10000) débitée de 5000.
        self.puce1.refresh_from_db()
        self.assertEqual(self.puce1.balance, Decimal('5000.00'))

    @mock.patch('core.tasks.check_transaction_timeout.apply_async')
    def test_reservation_empeche_la_survente(self, _timeout):
        """Deux transactions successives ne peuvent pas dépasser le solde global.

        Solde total = 15000. Une 1re transaction de 10000 réserve les fonds ;
        une 2e de 8000 doit échouer (il ne reste que 5000) — preuve que la
        réservation à la création protège de la double-dépense.
        """
        CompensationEngine.create_compensated_transaction(
            agent=self.agent, tx_type='DEPOT', amount=Decimal('10000'),
            target_operator='ORANGE', target_phone_number='07000002',
        )
        with self.assertRaises(ValueError):
            CompensationEngine.create_compensated_transaction(
                agent=self.agent, tx_type='DEPOT', amount=Decimal('8000'),
                target_operator='ORANGE', target_phone_number='07000002',
            )
        # Solde global restant = 5000 (10000 réservés sur 15000).
        total = sum(
            p.balance for p in Puce.objects.filter(agent=self.agent)
        )
        self.assertEqual(total, Decimal('5000.00'))

    @mock.patch('core.tasks.check_transaction_timeout.apply_async')
    def test_liste_transactions_pas_de_n_plus_1(self, _timeout):
        """La sérialisation de l'historique fait un nombre FIXE de requêtes.

        Avec prefetch (détails + puces) : 3 requêtes quel que soit le nombre de
        transactions (sinon N+1). Reproduit le queryset de TransactionViewSet.
        """
        from api.serializers import TransactionSerializer
        for _ in range(3):
            CompensationEngine.create_compensated_transaction(
                agent=self.agent, tx_type='DEPOT', amount=Decimal('1000'),
                target_operator='ORANGE', target_phone_number='07000002',
            )
        qs = (
            Transaction.objects.filter(agent=self.agent)
            .select_related('agent')
            .prefetch_related('compensation_details__puce')
            .order_by('-created_at')
        )
        # 1 (transactions) + 1 (détails prefetch) + 1 (puces prefetch).
        with self.assertNumQueries(3):
            _ = TransactionSerializer(qs, many=True).data

    @mock.patch('core.tasks.check_transaction_timeout.apply_async')
    def test_timeout_rembourse_les_fonds_reserves(self, _timeout):
        """À l'expiration d'une transaction PENDING, les fonds réservés sont rendus."""
        from core.tasks import check_transaction_timeout
        tx = CompensationEngine.create_compensated_transaction(
            agent=self.agent, tx_type='DEPOT', amount=Decimal('5000'),
            target_operator='ORANGE', target_phone_number='07000002',
        )
        self.puce1.refresh_from_db()
        self.assertEqual(self.puce1.balance, Decimal('5000.00'))  # réservé

        # Exécution directe du rollback de timeout.
        check_transaction_timeout(tx.id)

        self.puce1.refresh_from_db()
        self.assertEqual(self.puce1.balance, Decimal('10000.00'))  # remboursé
        tx.refresh_from_db()
        self.assertEqual(tx.status, 'FAILED')

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

    # --- Cas limites du moteur de compensation (plan de test §3.1) ---------

    def test_calculate_plan_ignore_puce_inactive(self):
        """Une puce inactive n'est pas comptee dans le solde disponible."""
        self.puce2.is_active = False
        self.puce2.save()
        # Seule puce1 (10000) est active -> 12000 doit echouer.
        with self.assertRaises(ValueError):
            CompensationEngine.calculate_plan(self.agent, Decimal('12000'))

    def test_calculate_plan_solde_exact(self):
        """Montant egal au solde global total : plan complet, aucune erreur."""
        plan = CompensationEngine.calculate_plan(self.agent, Decimal('15000'))
        total = sum(item['amount'] for item in plan)
        self.assertEqual(total, Decimal('15000'))

    def test_calculate_plan_ordonne_par_solde_decroissant(self):
        """La cascade commence par la puce au plus gros solde (puce1)."""
        plan = CompensationEngine.calculate_plan(self.agent, Decimal('3000'))
        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0]['puce'].id, self.puce1.id)

    def test_calculate_plan_montant_nul_ou_negatif_refuse(self):
        """Un montant <= 0 leve une ValueError (pas de plan)."""
        with self.assertRaises(ValueError):
            CompensationEngine.calculate_plan(self.agent, Decimal('0'))
        with self.assertRaises(ValueError):
            CompensationEngine.calculate_plan(self.agent, Decimal('-100'))


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

    def test_create_transfer(self):
        """Envoi P2P vers un numero : cree une transaction de type TRANSFERT."""
        response = self.client.post('/api/transactions/transfer/', {
            'amount': '5000',
            'target_operator': 'ORANGE',
            'target_phone_number': '07000002'
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('transaction_id', response.data)
        tx = Transaction.objects.get(id=response.data['transaction_id'])
        self.assertEqual(tx.type, 'TRANSFERT')
        self.assertEqual(tx.agent, self.agent)

    def test_create_transfer_invalid_amount(self):
        """Un transfert avec un montant trop petit est refuse (400)."""
        response = self.client.post('/api/transactions/transfer/', {
            'amount': '50',
            'target_operator': 'ORANGE',
            'target_phone_number': '07000002'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

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
        """Test la connexion admin (dashboard monte a la racine : /login/)."""
        response = self.client.post('/login/', {
            'username': 'admin',
            'password': 'Adminpass123!'
        })
        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_302_FOUND])

    def test_admin_dashboard_access(self):
        """Test l'accès au dashboard admin (home a la racine : /)."""
        self.client.login(username='admin', password='Adminpass123!')
        response = self.client.get('/')
        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_302_FOUND])


class RegisterSerializerTest(TestCase):
    """Tests de l'inscription (au niveau serializer, sans throttle)."""

    def _data(self, username, phone):
        # L'OTP est requis (lot A2) : on en génère un valide pour cet email.
        from api.services.otp import generate_and_send
        from core.models import EmailOtp
        email = f'{username}@test.com'
        generate_and_send(email, 'register')
        code = EmailOtp.objects.filter(
            email=email, is_used=False).latest('created_at').code
        return {
            'username': username,
            'email': email,
            'password': 'Passw0rd123',
            'password_confirm': 'Passw0rd123',
            'phone_number': phone,
            'first_name': 'Test',
            'last_name': 'Agent',
            'merchant_code': '8170275',  # requis pour un AGENT (lot D1)
            'otp': code,
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

    # --- D1 : code marchand -----------------------------------------------

    def test_register_agent_exige_code_marchand(self):
        """Un AGENT sans code marchand est refuse (lot D1)."""
        from api.serializers import RegisterSerializer
        data = self._data('agentnocode', '70222888')
        data.pop('merchant_code')
        s = RegisterSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('merchant_code', s.errors)

    def test_register_agent_stocke_code_marchand(self):
        """Le code marchand declare par l'agent est conserve."""
        from api.serializers import RegisterSerializer
        s = RegisterSerializer(data=self._data('agentcode', '70222999'))
        self.assertTrue(s.is_valid(), s.errors)
        agent = s.save().agent_profile
        self.assertEqual(agent.merchant_code, '8170275')

    def test_register_client_ignore_code_marchand(self):
        """Un CLIENT n'a pas de caisse : le code marchand est ignore (vide)."""
        from api.serializers import RegisterSerializer
        data = {**self._data('clientcode', '70223000'),
                'account_type': 'CLIENT', 'merchant_code': '9999999'}
        s = RegisterSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        agent = s.save().agent_profile
        self.assertEqual(agent.merchant_code, '')

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


class EmailOtpTest(TestCase):
    """OTP email à l'inscription (lot A2)."""

    def test_send_cree_un_code(self):
        from api.services.otp import generate_and_send
        from core.models import EmailOtp
        expires_in = generate_and_send('new@test.com', 'register')
        self.assertGreater(expires_in, 0)
        self.assertTrue(EmailOtp.objects.filter(
            email='new@test.com', is_used=False).exists())

    def test_verify_ok_consomme_le_code(self):
        from api.services.otp import generate_and_send, verify
        from core.models import EmailOtp
        generate_and_send('v@test.com', 'register')
        code = EmailOtp.objects.get(email='v@test.com', is_used=False).code
        ok, msg = verify('v@test.com', code, 'register')
        self.assertTrue(ok)
        # Rejoué -> refusé (déjà consommé).
        ok2, _ = verify('v@test.com', code, 'register')
        self.assertFalse(ok2)

    def test_verify_mauvais_code(self):
        from api.services.otp import generate_and_send, verify
        generate_and_send('w@test.com', 'register')
        ok, msg = verify('w@test.com', '000000', 'register')
        # Code aléatoire : extrêmement improbable d'être correct.
        if ok:
            self.skipTest('collision OTP improbable')
        self.assertIn('incorrect', msg.lower())

    def test_verify_verrouille_apres_max_tentatives(self):
        """Apres MAX_ATTEMPTS essais rates, le code est consomme (verrou)."""
        from api.services.otp import generate_and_send, verify
        from core.models import EmailOtp
        generate_and_send('lock@test.com', 'register')
        good = EmailOtp.objects.get(email='lock@test.com', is_used=False).code
        wrong = '000000' if good != '000000' else '111111'

        # MAX_ATTEMPTS essais errones : le dernier renvoie le message de verrou.
        for i in range(EmailOtp.MAX_ATTEMPTS):
            ok, msg = verify('lock@test.com', wrong, 'register')
            self.assertFalse(ok)
        self.assertIn('trop de tentatives', msg.lower())

        # Code consomme : meme le bon code est desormais refuse (renvoi requis).
        ok_good, msg_good = verify('lock@test.com', good, 'register')
        self.assertFalse(ok_good)
        self.assertIn('nouveau code', msg_good.lower())

    def test_verify_bon_code_avant_verrou(self):
        """Quelques essais rates puis le bon code : succes."""
        from api.services.otp import generate_and_send, verify
        from core.models import EmailOtp
        generate_and_send('ok2@test.com', 'register')
        good = EmailOtp.objects.get(email='ok2@test.com', is_used=False).code
        wrong = '000000' if good != '000000' else '111111'
        verify('ok2@test.com', wrong, 'register')
        verify('ok2@test.com', wrong, 'register')
        ok, _ = verify('ok2@test.com', good, 'register')
        self.assertTrue(ok)

    def test_register_sans_otp_refuse(self):
        from api.serializers import RegisterSerializer
        data = {
            'username': 'nootp', 'email': 'nootp@test.com',
            'password': 'Passw0rd123', 'password_confirm': 'Passw0rd123',
            'phone_number': '70333111', 'first_name': 'N', 'last_name': 'O',
        }
        s = RegisterSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('otp', s.errors)

    def test_register_mauvais_otp_refuse(self):
        from api.serializers import RegisterSerializer
        data = {
            'username': 'badotp', 'email': 'badotp@test.com',
            'password': 'Passw0rd123', 'password_confirm': 'Passw0rd123',
            'phone_number': '70333222', 'first_name': 'B', 'last_name': 'O',
            'merchant_code': '8170275', 'otp': '123456',
        }
        s = RegisterSerializer(data=data)
        # Champ valide en forme, mais vérification échoue à la création.
        self.assertTrue(s.is_valid(), s.errors)
        from rest_framework import serializers as drf
        with self.assertRaises(drf.ValidationError):
            s.save()


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


class LoginByPhoneTest(APITestCase):
    """Lot A3 : l'identifiant de connexion est le numéro de téléphone.

    Le username reste accepté en repli (comptes existants / démo).
    """

    def setUp(self):
        from django.core.cache import cache
        cache.clear()  # repartir d'un compteur de throttle 'login' propre
        self.user = User.objects.create_user(
            'phoneagent', 'phone@test.com', 'Passw0rd123'
        )
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70112233',
            first_name='P', last_name='A', kyc_status='PENDING',
        )

    def test_login_par_numero_de_telephone(self):
        resp = self.client.post('/api/auth/login/', {
            'phone_number': '70112233', 'password': 'Passw0rd123',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)

    def test_login_par_numero_avec_indicatif(self):
        """Un numéro avec préfixe +226 doit être normalisé et résolu."""
        resp = self.client.post('/api/auth/login/', {
            'phone_number': '+22670112233', 'password': 'Passw0rd123',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)

    def test_repli_username_toujours_accepte(self):
        resp = self.client.post('/api/auth/login/', {
            'phone_number': 'phoneagent', 'password': 'Passw0rd123',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)

    def test_mauvais_mot_de_passe_refuse(self):
        resp = self.client.post('/api/auth/login/', {
            'phone_number': '70112233', 'password': 'wrong',
        })
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class DeviceBindingTest(APITestCase):
    """Lot A4 : liaison appareil + vérification OTP des nouveaux appareils."""

    def setUp(self):
        from django.core.cache import cache
        from core.models import TrustedDevice, EmailOtp  # noqa: F401
        cache.clear()  # compteur de throttle 'login' propre par test
        self.user = User.objects.create_user(
            'devuser', 'dev@test.com', 'Passw0rd123'
        )
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70123400',
            first_name='D', last_name='V', kyc_status='PENDING',
        )

    def _login(self, device_id='dev-A', password='Passw0rd123'):
        return self.client.post('/api/auth/login/', {
            'phone_number': '70123400', 'password': password,
            'device_id': device_id, 'device_name': 'Test',
        })

    def test_premier_appareil_approuve_automatiquement(self):
        from core.models import TrustedDevice
        resp = self._login(device_id='dev-A')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)
        self.assertTrue(
            TrustedDevice.objects.filter(agent=self.agent, device_id='dev-A').exists()
        )

    def test_appareil_connu_reconnecte_sans_otp(self):
        self._login(device_id='dev-A')  # enrôle dev-A
        resp = self._login(device_id='dev-A')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)

    def test_nouvel_appareil_exige_otp(self):
        from core.models import EmailOtp
        self._login(device_id='dev-A')  # 1er appareil de confiance
        resp = self._login(device_id='dev-B')  # nouvel appareil
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(resp.data.get('device_verification_required'))
        self.assertIn('@', resp.data.get('email', ''))
        # Un OTP 'device' a bien été généré
        self.assertTrue(
            EmailOtp.objects.filter(
                email='dev@test.com', purpose=EmailOtp.PURPOSE_DEVICE, is_used=False
            ).exists()
        )

    def test_login_sans_device_id_reste_legacy(self):
        """Pas de device_id (web/admin) -> jetons émis, pas de binding."""
        resp = self.client.post('/api/auth/login/', {
            'phone_number': '70123400', 'password': 'Passw0rd123',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)

    def test_verify_device_avec_bon_otp_emet_jetons(self):
        from core.models import EmailOtp, TrustedDevice
        self._login(device_id='dev-A')
        self._login(device_id='dev-B')  # déclenche l'OTP
        otp = EmailOtp.objects.filter(
            email='dev@test.com', purpose=EmailOtp.PURPOSE_DEVICE, is_used=False
        ).latest('created_at')
        resp = self.client.post('/api/auth/device/verify/', {
            'phone_number': '70123400', 'password': 'Passw0rd123',
            'device_id': 'dev-B', 'device_name': 'Test', 'otp': otp.code,
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)
        self.assertTrue(
            TrustedDevice.objects.filter(agent=self.agent, device_id='dev-B').exists()
        )

    def test_verify_device_mauvais_otp_refuse(self):
        self._login(device_id='dev-A')
        self._login(device_id='dev-B')
        resp = self.client.post('/api/auth/device/verify/', {
            'phone_number': '70123400', 'password': 'Passw0rd123',
            'device_id': 'dev-B', 'device_name': 'Test', 'otp': '000000',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('otp', resp.data)


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class PasswordResetTest(APITestCase):
    """Lot A5 : réinitialisation du mot de passe par OTP email."""

    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.user = User.objects.create_user(
            'resetuser', 'reset@test.com', 'OldPassw0rd1'
        )
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70900011',
            first_name='R', last_name='U', kyc_status='PENDING',
            pin_code='1234',
        )

    def _request(self, identifier='70900011'):
        return self.client.post('/api/auth/password/reset/request/', {
            'identifier': identifier,
        })

    def _latest_otp(self):
        from core.models import EmailOtp
        return EmailOtp.objects.filter(
            email='reset@test.com', purpose=EmailOtp.PURPOSE_RESET, is_used=False
        ).latest('created_at')

    def test_request_par_telephone_envoie_otp(self):
        from core.models import EmailOtp
        resp = self._request('70900011')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(EmailOtp.objects.filter(
            email='reset@test.com', purpose=EmailOtp.PURPOSE_RESET).exists())

    def test_request_compte_inconnu_reste_neutre(self):
        from core.models import EmailOtp
        resp = self._request('70999999')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)  # pas d'enum
        self.assertFalse(EmailOtp.objects.exists())

    def test_confirm_change_le_mot_de_passe_et_efface_pin(self):
        self._request('70900011')
        otp = self._latest_otp()
        resp = self.client.post('/api/auth/password/reset/confirm/', {
            'identifier': '70900011', 'otp': otp.code,
            'new_password': 'NewPassw0rd9',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.agent.refresh_from_db()
        self.assertTrue(self.user.check_password('NewPassw0rd9'))
        self.assertIsNone(self.agent.pin_code)

    def test_confirm_login_avec_nouveau_mdp(self):
        self._request('70900011')
        otp = self._latest_otp()
        self.client.post('/api/auth/password/reset/confirm/', {
            'identifier': '70900011', 'otp': otp.code,
            'new_password': 'NewPassw0rd9',
        })
        login = self.client.post('/api/auth/login/', {
            'phone_number': '70900011', 'password': 'NewPassw0rd9',
        })
        self.assertEqual(login.status_code, status.HTTP_200_OK)

    def test_confirm_mauvais_otp_refuse(self):
        self._request('70900011')
        resp = self.client.post('/api/auth/password/reset/confirm/', {
            'identifier': '70900011', 'otp': '000000',
            'new_password': 'NewPassw0rd9',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('otp', resp.data)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('OldPassw0rd1'))

    def test_confirm_mot_de_passe_faible_refuse(self):
        self._request('70900011')
        otp = self._latest_otp()
        resp = self.client.post('/api/auth/password/reset/confirm/', {
            'identifier': '70900011', 'otp': otp.code, 'new_password': '123',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('new_password', resp.data)


class PinStrengthTest(APITestCase):
    """Lot A6 : refus des PIN triviaux à la création."""

    def setUp(self):
        self.user = User.objects.create_user('pinuser', 'pin@test.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70700070',
            first_name='P', last_name='N', kyc_status='PENDING',
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_unit_weak_pin_reason(self):
        # Parite front/back : meme corpus que sic_mobile/test/core/pin_rules_test.dart
        # (toute modif ici doit y etre repercutee).
        from api.services.pin_rules import weak_pin_reason
        for weak in ['0000', '1111', '1234', '4321', '2345', '987654', '111111']:
            self.assertIsNotNone(weak_pin_reason(weak), f'{weak} devrait etre faible')
        for ok in ['1357', '2580', '1928', '4071']:
            self.assertIsNone(weak_pin_reason(ok), f'{ok} devrait etre accepte')

    def _setup(self, pin):
        return self.client.post('/api/auth/pin/setup/', {
            'password': 'Passw0rd123', 'pin': pin, 'pin_confirm': pin,
        })

    def test_pin_trivial_refuse(self):
        resp = self._setup('1234')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('pin', resp.data)

    def test_pin_repete_refuse(self):
        resp = self._setup('0000')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('pin', resp.data)

    def test_pin_robuste_accepte(self):
        resp = self._setup('1357')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.assertIsNotNone(self.agent.pin_code)


import tempfile  # noqa: E402


@override_settings(MEDIA_ROOT=tempfile.mkdtemp())
class KycSubmitTest(APITestCase):
    """Lot C3 : soumission et revue d'un dossier KYC (montée de palier)."""

    def setUp(self):
        from django.core.files.uploadedfile import SimpleUploadedFile  # noqa: F401
        self.user = User.objects.create_user('kycuser', 'kyc@test.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70600060',
            first_name='K', last_name='Y', kyc_status='PENDING', kyc_tier=0,
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def _doc(self, name='id.jpg'):
        from django.core.files.uploadedfile import SimpleUploadedFile
        return SimpleUploadedFile(name, b'fake-image-bytes', content_type='image/jpeg')

    def test_submit_tier1_passe_en_submitted(self):
        resp = self.client.post('/api/auth/kyc/submit/', {
            'requested_tier': 1, 'id_card_front': self._doc(),
        }, format='multipart')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.assertEqual(self.agent.kyc_status, 'SUBMITTED')
        self.assertEqual(self.agent.kyc_requested_tier, 1)
        self.assertTrue(self.agent.id_card_front_url)
        self.assertIsNotNone(self.agent.kyc_submitted_at)

    def test_submit_tier1_sans_piece_refuse(self):
        resp = self.client.post('/api/auth/kyc/submit/', {
            'requested_tier': 1,
        }, format='multipart')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('id_card_front', resp.data)

    def test_submit_tier2_sans_selfie_refuse(self):
        resp = self.client.post('/api/auth/kyc/submit/', {
            'requested_tier': 2, 'id_card_front': self._doc(),
        }, format='multipart')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('selfie', resp.data)

    def test_submit_palier_non_superieur_refuse(self):
        self.agent.kyc_tier = 1
        self.agent.save()
        resp = self.client.post('/api/auth/kyc/submit/', {
            'requested_tier': 1, 'id_card_front': self._doc(),
        }, format='multipart')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_review_approve_monte_le_palier(self):
        self.client.post('/api/auth/kyc/submit/', {
            'requested_tier': 1, 'id_card_front': self._doc(),
        }, format='multipart')
        # Admin
        admin = User.objects.create_superuser('adm', 'adm@test.com', 'Passw0rd123')
        refresh = RefreshToken.for_user(admin)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        resp = self.client.post('/api/auth/kyc/review/', {
            'agent_id': str(self.agent.id), 'decision': 'approve',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.assertEqual(self.agent.kyc_tier, 1)
        self.assertEqual(self.agent.kyc_status, 'APPROVED')

    def test_review_reject_enregistre_motif(self):
        admin = User.objects.create_superuser('adm2', 'adm2@test.com', 'Passw0rd123')
        refresh = RefreshToken.for_user(admin)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        resp = self.client.post('/api/auth/kyc/review/', {
            'agent_id': str(self.agent.id), 'decision': 'reject',
            'reason': 'Photo illisible',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.assertEqual(self.agent.kyc_status, 'REJECTED')
        self.assertEqual(self.agent.kyc_rejection_reason, 'Photo illisible')
        self.assertEqual(self.agent.kyc_tier, 0)

    def test_review_non_admin_refuse(self):
        resp = self.client.post('/api/auth/kyc/review/', {
            'agent_id': str(self.agent.id), 'decision': 'approve',
        })
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)


class LogoutBlacklistTest(APITestCase):
    """Securite : le logout blackliste le refresh token (session revocable)."""

    def setUp(self):
        self.user = User.objects.create_user('logoutuser', 'lo@test.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70445566',
            first_name='L', last_name='O', kyc_status='PENDING',
        )
        self.refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.refresh.access_token}')

    def test_logout_blackliste_le_refresh(self):
        resp = self.client.post('/api/auth/logout/', {'refresh': str(self.refresh)})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        # Le refresh blackliste ne doit plus pouvoir produire un access token.
        self.client.credentials()  # retirer l'en-tete d'auth
        again = self.client.post('/api/auth/refresh/', {'refresh': str(self.refresh)})
        self.assertEqual(again.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_logout_sans_refresh_refuse(self):
        resp = self.client.post('/api/auth/logout/', {})
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class ThrottlingTest(APITestCase):
    """Securite : la limite de debit login (5/min) renvoie 429 au-dela."""

    def setUp(self):
        from django.core.cache import cache
        cache.clear()  # compteur de throttle propre
        self.user = User.objects.create_user('throttleuser', 'th@test.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70778899',
            first_name='T', last_name='H', kyc_status='PENDING',
        )

    def test_login_au_dela_du_quota_renvoie_429(self):
        # Le scope 'login' est a 5/minute : la 6e tentative doit etre etranglee.
        last_status = None
        for _ in range(6):
            resp = self.client.post('/api/auth/login/', {
                'phone_number': '70778899', 'password': 'Passw0rd123',
            })
            last_status = resp.status_code
        self.assertEqual(last_status, status.HTTP_429_TOO_MANY_REQUESTS)


class CompensationWebhookTest(TestCase):
    """Securite fonds (modele reservation) : les fonds sont debites a la creation.

    Le webhook SUCCESS ne re-debite donc PAS (sinon double comptage) ; un FAILED
    rembourse les fonds reserves. Tout est idempotent (anti rejeu).
    """

    def setUp(self):
        self.user = User.objects.create_user('whuser', 'wh@test.com', 'Passw0rd123')
        self.agent = Agent.objects.create(
            user=self.user, phone_number='70554433',
            first_name='W', last_name='H', kyc_status='APPROVED',
        )
        # La puce est deja a 7000 : 3000 ont ete RESERVES (debites) a la creation
        # de la transaction (modele reservation).
        self.puce = Puce.objects.create(
            agent=self.agent, operator='ORANGE',
            phone_number='+224620010001', balance=Decimal('7000.00'),
        )
        self.tx = Transaction.objects.create(
            agent=self.agent, type='DEPOT', status='PENDING',
            amount=Decimal('3000.00'), target_operator='ORANGE',
            target_phone_number='70000009',
        )
        self.detail = CompensationDetail.objects.create(
            transaction=self.tx, puce=self.puce,
            amount_deducted=Decimal('3000.00'), status='PENDING',
            cinetpay_ref='REF_TEST_1',
        )

    def test_webhook_success_ne_redebite_pas(self):
        # Les fonds sont deja reserves : le SUCCESS confirme sans re-debiter.
        CompensationEngine.process_webhook('REF_TEST_1', 'SUCCESS')
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('7000.00'))
        self.detail.refresh_from_db()
        self.assertEqual(self.detail.status, 'SUCCESS')
        self.tx.refresh_from_db()
        self.assertEqual(self.tx.status, 'COMPLETED')

        # Rejeu du meme webhook : aucun effet (idempotence).
        CompensationEngine.process_webhook('REF_TEST_1', 'SUCCESS')
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('7000.00'))

    def test_webhook_failed_rembourse_les_fonds_reserves(self):
        # Un echec recredite les 3000 reserves -> retour a 10000.
        CompensationEngine.process_webhook('REF_TEST_1', 'FAILED')
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('10000.00'))
        self.detail.refresh_from_db()
        self.assertEqual(self.detail.status, 'FAILED')
        self.tx.refresh_from_db()
        self.assertEqual(self.tx.status, 'FAILED')

        # Rejeu : pas de double remboursement (idempotence).
        CompensationEngine.process_webhook('REF_TEST_1', 'FAILED')
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('10000.00'))

    def test_webhook_reference_inconnue(self):
        tx, ok = CompensationEngine.process_webhook('REF_INEXISTANTE', 'SUCCESS')
        self.assertIsNone(tx)
        self.assertFalse(ok)


class AlertConfigAPITest(APITestCase):
    """Seuils d'alerte de solde par puce (modele + signal + endpoints)."""

    def setUp(self):
        from core.models import AlertConfig
        self.AlertConfig = AlertConfig

        self.user = User.objects.create_user(
            username='alertagent', email='alert@example.com',
            password='Testpass123!'
        )
        self.agent = Agent.objects.create(
            user=self.user, phone_number='+22612000001',
            first_name='Alert', last_name='Agent', kyc_status='APPROVED'
        )
        self.puce = Puce.objects.create(
            agent=self.agent, operator='ORANGE',
            phone_number='+22670000001', balance=Decimal('100000.00')
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}'
        )

    def test_signal_cree_alerte_par_defaut(self):
        """Creer une puce cree automatiquement une alerte (seuil 50000, active)."""
        config = self.AlertConfig.objects.get(puce=self.puce)
        self.assertEqual(config.threshold, Decimal('50000'))
        self.assertTrue(config.is_enabled)

    def test_liste_alertes_de_l_agent(self):
        response = self.client.get('/api/alerts/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        item = response.data['results'][0]
        self.assertEqual(item['operator'], 'ORANGE')
        self.assertEqual(item['phone_number'], '+22670000001')
        self.assertEqual(str(item['puce_id']), str(self.puce.id))

    def test_patch_met_a_jour_seuil_et_activation(self):
        config = self.AlertConfig.objects.get(puce=self.puce)
        response = self.client.patch(
            f'/api/alerts/{config.id}/',
            {'threshold': '75000', 'is_enabled': False}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        config.refresh_from_db()
        self.assertEqual(config.threshold, Decimal('75000'))
        self.assertFalse(config.is_enabled)

    def test_seuil_negatif_refuse(self):
        config = self.AlertConfig.objects.get(puce=self.puce)
        response = self.client.patch(
            f'/api/alerts/{config.id}/',
            {'threshold': '-100'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_isolation_entre_agents(self):
        """Un agent ne voit ni ne modifie l'alerte de la puce d'un autre."""
        other_user = User.objects.create_user(
            username='other', email='other@example.com', password='Testpass123!'
        )
        other_agent = Agent.objects.create(
            user=other_user, phone_number='+22612000002',
            first_name='Other', last_name='Agent', kyc_status='APPROVED'
        )
        other_puce = Puce.objects.create(
            agent=other_agent, operator='MOOV',
            phone_number='+22670000002', balance=Decimal('10000.00')
        )
        other_config = self.AlertConfig.objects.get(puce=other_puce)

        # Liste : ne contient pas la puce de l'autre agent.
        response = self.client.get('/api/alerts/')
        ids = [r['id'] for r in response.data['results']]
        self.assertNotIn(str(other_config.id), ids)

        # PATCH sur l'alerte d'autrui : 404 (hors queryset).
        response = self.client.patch(
            f'/api/alerts/{other_config.id}/',
            {'threshold': '1'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_non_authentifie_refuse(self):
        self.client.credentials()
        response = self.client.get('/api/alerts/')
        self.assertIn(response.status_code, (401, 403))


class SetBalanceAPITest(APITestCase):
    """Mise à jour manuelle (réconciliation) du solde d'une puce, par l'agent."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='balagent', email='bal@example.com', password='Testpass123!'
        )
        self.agent = Agent.objects.create(
            user=self.user, phone_number='+22612000010',
            first_name='Bal', last_name='Agent', kyc_status='APPROVED'
        )
        self.puce = Puce.objects.create(
            agent=self.agent, operator='ORANGE',
            phone_number='+22670000010', balance=Decimal('50000.00')
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}'
        )

    def _url(self, puce):
        return f'/api/puces/{puce.id}/set_balance/'

    def test_proprietaire_sans_pin_met_a_jour(self):
        response = self.client.post(
            self._url(self.puce), {'balance': '123456.78'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('123456.78'))

    def test_solde_negatif_refuse(self):
        response = self.client.post(
            self._url(self.puce), {'balance': '-1'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('50000.00'))

    def test_solde_invalide_refuse(self):
        response = self.client.post(
            self._url(self.puce), {'balance': 'abc'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_pin_configure_sans_token_refuse(self):
        self.agent.pin_code = 'hashed-pin'
        self.agent.save(update_fields=['pin_code'])
        response = self.client.post(
            self._url(self.puce), {'balance': '60000'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('50000.00'))

    def test_pin_configure_avec_token_valide(self):
        from django.core import signing
        self.agent.pin_code = 'hashed-pin'
        self.agent.save(update_fields=['pin_code'])
        token = signing.dumps({'agent_id': str(self.agent.id)}, salt='pin-token')
        response = self.client.post(
            self._url(self.puce),
            {'balance': '60000', 'pin_token': token}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.puce.refresh_from_db()
        self.assertEqual(self.puce.balance, Decimal('60000.00'))

    def test_non_proprietaire_404(self):
        other_user = User.objects.create_user(
            username='intrus', email='intrus@example.com', password='Testpass123!'
        )
        other_agent = Agent.objects.create(
            user=other_user, phone_number='+22612000011',
            first_name='Intrus', last_name='Agent', kyc_status='APPROVED'
        )
        other_puce = Puce.objects.create(
            agent=other_agent, operator='MOOV',
            phone_number='+22670000011', balance=Decimal('1000.00')
        )
        response = self.client.post(
            self._url(other_puce), {'balance': '999999'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        other_puce.refresh_from_db()
        self.assertEqual(other_puce.balance, Decimal('1000.00'))
