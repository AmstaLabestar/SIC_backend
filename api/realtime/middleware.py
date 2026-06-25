"""Authentification des connexions WebSocket par JWT (lot temps reel).

Channels n'authentifie pas via le JWT par defaut (il s'appuie sur la session).
Ce middleware lit le jeton d'acces passe en query string (`?token=...`),
le valide, et place l'agent correspondant dans `scope['agent']` (ou `None`).
"""
from urllib.parse import parse_qs

from channels.db import database_sync_to_async


@database_sync_to_async
def _agent_from_token(token):
    if not token:
        return None
    from django.contrib.auth.models import User
    from rest_framework_simplejwt.exceptions import TokenError
    from rest_framework_simplejwt.tokens import AccessToken

    try:
        access = AccessToken(token)  # valide signature + expiration
        user_id = access.get('user_id')
    except TokenError:
        return None
    if not user_id:
        return None
    try:
        user = User.objects.select_related('agent_profile').get(id=user_id)
    except User.DoesNotExist:
        return None
    return getattr(user, 'agent_profile', None)


class JWTAuthMiddleware:
    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        qs = parse_qs(scope.get('query_string', b'').decode())
        token = (qs.get('token') or [None])[0]
        scope['agent'] = await _agent_from_token(token)
        return await self.inner(scope, receive, send)
