from core.models import ActivityLog, Agent

def notifications(request):
    if request.user.is_authenticated and request.user.is_staff:
        # Get recent important logs for notifications
        recent_notifications = ActivityLog.objects.exclude(level='INFO').order_by('-created_at')[:5]
        unread_count = ActivityLog.objects.exclude(level='INFO').filter(is_read=False).count()
        # Dossiers KYC en attente de revue (badge du menu admin).
        pending_kyc_count = Agent.objects.filter(kyc_status='SUBMITTED').count()
        return {
            'recent_notifications': recent_notifications,
            'unread_notifications_count': unread_count,
            'pending_kyc_count': pending_kyc_count,
        }
    # Hors session staff : valeur par defaut pour eviter les erreurs de template.
    return {'pending_kyc_count': 0}
