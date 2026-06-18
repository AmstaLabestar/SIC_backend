"""Signaux du domaine core."""
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Puce, AlertConfig


@receiver(post_save, sender=Puce)
def create_default_alert_config(sender, instance, created, **kwargs):
    """A la creation d'une puce, lui attacher une alerte de solde par defaut.

    Idempotent (get_or_create) : ne recree rien si la config existe deja.
    """
    if created:
        AlertConfig.objects.get_or_create(puce=instance)
