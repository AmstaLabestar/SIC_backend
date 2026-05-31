from rest_framework import permissions

class IsApprovedAgent(permissions.BasePermission):
    """
    Permet l'accès uniquement aux agents ayant un statut KYC 'APPROVED' 
    et n'étant pas suspendus.
    """
    message = 'Votre compte agent doit être approuvé (KYC) et actif pour effectuer cette action.'

    def has_permission(self, request, view):
        # On vérifie d'abord que l'utilisateur est authentifié
        if not request.user or not request.user.is_authenticated:
            return False
            
        # On vérifie si l'agent existe et est approuvé
        agent = getattr(request.user, 'agent_profile', None)
        if agent and agent.kyc_status == 'APPROVED' and not agent.is_suspended:
            return True
            
        return False




