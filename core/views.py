"""
Vues principales du module core
"""
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import requires_csrf_token
from django.utils import timezone


def home(request):
    """Page d'accueil par défaut."""
    return render(request, 'core/home.html')


@requires_csrf_token
def csrf_failure(request, reason=""):
    """
    Vue personnalisée pour les erreurs CSRF.

    Retourne une réponse JSON pour les requêtes API,
    ou une page HTML pour le dashboard.
    """
    if request.headers.get('Accept') == 'application/json' or \
       request.path.startswith('/api/'):
        return JsonResponse({
            'error': 'CSRF verification failed',
            'reason': 'Your session has expired or the form token is invalid.',
            'code': 'CSRF_FAILURE'
        }, status=403)

    return render(request, 'core/csrf_error.html', {
        'reason': reason,
        'timestamp': timezone.now()
    }, status=403)


def handler404(request, exception):
    """Gestionnaire d'erreur 404."""
    if request.headers.get('Accept') == 'application/json' or \
       request.path.startswith('/api/'):
        return JsonResponse({
            'error': 'Resource not found',
            'path': request.path,
            'code': 'NOT_FOUND'
        }, status=404)

    return render(request, 'core/404.html', status=404)


def handler500(request):
    """Gestionnaire d'erreur 500."""
    if request.headers.get('Accept') == 'application/json' or \
       request.path.startswith('/api/'):
        return JsonResponse({
            'error': 'Internal server error',
            'code': 'SERVER_ERROR'
        }, status=500)

    return render(request, 'core/500.html', status=500)


def handler403(request, exception):
    """Gestionnaire d'erreur 403."""
    if request.headers.get('Accept') == 'application/json' or \
       request.path.startswith('/api/'):
        return JsonResponse({
            'error': 'Permission denied',
            'code': 'FORBIDDEN'
        }, status=403)

    return render(request, 'core/403.html', status=403)