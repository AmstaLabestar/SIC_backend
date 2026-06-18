from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = 'core'

    def ready(self):
        # Enregistre les recepteurs de signaux (creation auto d'AlertConfig).
        from . import signals  # noqa: F401
