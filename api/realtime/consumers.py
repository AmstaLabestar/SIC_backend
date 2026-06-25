"""Consumer WebSocket des notifications temps reel (lot temps reel).

Chaque agent rejoint le groupe `agent_<id>` a la connexion. Le backend pousse
des evenements via `notify_agent()` ; le consumer les relaie au client.

Principe fintech : le WebSocket n'est qu'un canal de *liveness*. La verite
reste la base via REST. Le client re-synchronise (re-fetch) a chaque connexion.
"""
import json

from channels.generic.websocket import AsyncWebsocketConsumer


class NotificationsConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        agent = self.scope.get('agent')
        if agent is None:
            # 4401 : non authentifie (jeton absent/invalide).
            await self.close(code=4401)
            return
        self.group_name = f'agent_{agent.id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.send(text_data=json.dumps({'type': 'connected'}))

    async def disconnect(self, code):
        group = getattr(self, 'group_name', None)
        if group is not None:
            await self.channel_layer.group_discard(group, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # Cote client : seulement un heartbeat de maintien de connexion.
        try:
            data = json.loads(text_data or '{}')
        except (ValueError, TypeError):
            return
        if data.get('type') == 'ping':
            await self.send(text_data=json.dumps({'type': 'pong'}))

    async def notify(self, event):
        # event = {'type': 'notify', 'data': {...}} (envoye par group_send).
        await self.send(text_data=json.dumps(event['data']))
