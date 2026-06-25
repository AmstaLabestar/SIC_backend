import os
from celery import Celery
from celery.schedules import crontab

# Définir le module de configuration Django par défaut pour 'celery'.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('sic_platform')

# Utiliser les paramètres Django pour configurer Celery.
# Le namespace 'CELERY' signifie que toutes les clés de configuration liées à Celery
# doivent commencer par 'CELERY_'.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Découvrir automatiquement les tâches asynchrones dans les applications installées (tasks.py).
app.autodiscover_tasks()

# Tâches périodiques (exécutées par `celery -A config beat`).
app.conf.beat_schedule = {
    # Filet de sécurité : rattrape les transactions PENDING périmées (eta perdu
    # / webhook manqué) toutes les 5 minutes.
    'reconcile-stale-transactions': {
        'task': 'core.tasks.reconcile_stale_transactions',
        'schedule': 300.0,
    },
    # Purge des OTP expirés, chaque jour à 03h00.
    'cleanup-expired-otps': {
        'task': 'core.tasks.cleanup_expired_otps',
        'schedule': crontab(hour=3, minute=0),
    },
}
