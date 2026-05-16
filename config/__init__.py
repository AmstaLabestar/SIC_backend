# Assurez-vous que l'application Celery est toujours importée lorsque
# Django démarre pour que l'annotation @shared_task fonctionne.
from .celery import app as celery_app

__all__ = ('celery_app',)
