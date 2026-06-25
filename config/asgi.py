"""
ASGI config for config project.

Route le HTTP vers Django et le WebSocket vers Channels (notifications temps
reel, authentifiees par JWT). Le serveur ASGI (daphne) sert les deux.
"""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Initialise Django (apps/modeles) AVANT d'importer les consumers.
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402
from api.realtime.middleware import JWTAuthMiddleware  # noqa: E402
from api.realtime.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter({
    'http': django_asgi_app,
    'websocket': JWTAuthMiddleware(URLRouter(websocket_urlpatterns)),
})
