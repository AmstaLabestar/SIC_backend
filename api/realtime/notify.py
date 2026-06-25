"""Emission d'evenements temps reel vers le canal d'un agent (lot temps reel).

`notify_agent` est appelable depuis du code synchrone (vues, services). Elle ne
doit JAMAIS propager d'erreur : une notification ratee n'annule pas une
transaction (la verite reste en base, le client re-synchronise au besoin).
"""
import logging

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

logger = logging.getLogger('sic.realtime')


def notify_agent(agent_id, payload):
    """Pousse `payload` (JSON-serialisable) vers le groupe `agent_<id>`."""
    if agent_id is None:
        return
    layer = get_channel_layer()
    if layer is None:
        return
    try:
        async_to_sync(layer.group_send)(
            f'agent_{agent_id}',
            {'type': 'notify', 'data': payload},
        )
    except Exception:  # noqa: BLE001 — la notif ne doit jamais casser l'appelant
        logger.warning("notify_agent: echec d'emission", exc_info=True)
