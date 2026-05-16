import os
from celery import Celery

# Définir le module de configuration Django par défaut pour 'celery'.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('sic_platform')

# Utiliser les paramètres Django pour configurer Celery.
# Le namespace 'CELERY' signifie que toutes les clés de configuration liées à Celery
# doivent commencer par 'CELERY_'.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Découvrir automatiquement les tâches asynchrones dans les applications installées (tasks.py).
app.autodiscover_tasks()
