from core.models import ActivityLog

def notifications(request):
    if request.user.is_authenticated and request.user.is_staff:
        # Get recent important logs for notifications
        recent_notifications = ActivityLog.objects.exclude(level='INFO').order_by('-created_at')[:5]
        unread_count = ActivityLog.objects.exclude(level='INFO').filter(is_read=False).count()
        return {
            'recent_notifications': recent_notifications,
            'unread_notifications_count': unread_count
        }
    return {}
