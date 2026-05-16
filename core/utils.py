from .models import ActivityLog

def log_activity(user=None, agent=None, action="", description="", level="INFO", ip_address=None):
    """
    Utility function to log an activity securely.
    """
    try:
        ActivityLog.objects.create(
            user=user,
            agent=agent,
            action=action,
            description=description,
            level=level,
            ip_address=ip_address
        )
    except Exception as e:
        # Silently fail so we don't break the main flow, but in production we'd use logging
        print(f"Failed to log activity: {str(e)}")
