"""Tests du socle temps reel (WebSocket Channels)."""
from asgiref.sync import async_to_sync
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from django.contrib.auth.models import User
from django.test import TransactionTestCase, override_settings
from rest_framework_simplejwt.tokens import RefreshToken

from config.asgi import application
from core.models import Agent


@override_settings(CHANNEL_LAYERS={
    'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}
})
class RealtimeWebSocketTest(TransactionTestCase):
    """Connexion authentifiee par JWT + reception d'un evenement pousse."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='wsagent', email='ws@example.com', password='Testpass123!'
        )
        self.agent = Agent.objects.create(
            user=self.user, phone_number='+22612000099',
            first_name='Ws', last_name='Agent', kyc_status='APPROVED'
        )
        self.token = str(RefreshToken.for_user(self.user).access_token)

    def test_connexion_refusee_sans_token(self):
        async def scenario():
            communicator = WebsocketCommunicator(application, '/ws/notifications/')
            connected, _ = await communicator.connect()
            self.assertFalse(connected)
            await communicator.disconnect()

        async_to_sync(scenario)()

    def test_connexion_refusee_token_invalide(self):
        async def scenario():
            communicator = WebsocketCommunicator(
                application, '/ws/notifications/?token=pas-un-jwt'
            )
            connected, _ = await communicator.connect()
            self.assertFalse(connected)
            await communicator.disconnect()

        async_to_sync(scenario)()

    def test_connexion_et_reception_evenement(self):
        async def scenario():
            communicator = WebsocketCommunicator(
                application, f'/ws/notifications/?token={self.token}'
            )
            connected, _ = await communicator.connect()
            self.assertTrue(connected)

            hello = await communicator.receive_json_from()
            self.assertEqual(hello['type'], 'connected')

            # Import tardif : notify_agent lit le channel layer (overridden).
            from api.realtime.notify import notify_agent
            await database_sync_to_async(notify_agent)(
                self.agent.id,
                {'type': 'tx.created', 'transaction_id': 'abc', 'status': 'PENDING'},
            )

            msg = await communicator.receive_json_from()
            self.assertEqual(msg['type'], 'tx.created')
            self.assertEqual(msg['transaction_id'], 'abc')
            await communicator.disconnect()

        async_to_sync(scenario)()

    def test_isolation_entre_agents(self):
        """Un evenement pour un autre agent n'arrive pas sur ce socket."""
        async def scenario():
            communicator = WebsocketCommunicator(
                application, f'/ws/notifications/?token={self.token}'
            )
            connected, _ = await communicator.connect()
            self.assertTrue(connected)
            await communicator.receive_json_from()  # 'connected'

            from api.realtime.notify import notify_agent
            # Emission vers un autre agent (id quelconque).
            await database_sync_to_async(notify_agent)(
                'autre-agent-id', {'type': 'tx.created'}
            )
            self.assertTrue(await communicator.receive_nothing(timeout=0.3))
            await communicator.disconnect()

        async_to_sync(scenario)()
