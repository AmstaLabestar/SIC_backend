"""
URLs pour l'API SIC - Configuration des routes API
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import (
    TokenRefreshView,
    TokenVerifyView,
)
from .views import (
    TransactionViewSet, PuceViewSet, AgentProfileView,
    RegisterView, CommissionInfoView, HealthCheckView,
    CustomTokenObtainPairView, LogoutView,
    PinSetupView, PinVerifyView,
    BiometricRegisterView, BiometricLoginView, BiometricDeviceListView
)

router = DefaultRouter()
router.register(r'transactions', TransactionViewSet, basename='transaction')
router.register(r'puces', PuceViewSet, basename='puce')

urlpatterns = [
    # Authentication
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/verify/', TokenVerifyView.as_view(), name='token_verify'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('auth/profile/', AgentProfileView.as_view(), name='agent_profile'),

    # Code PIN
    path('auth/pin/setup/', PinSetupView.as_view(), name='pin_setup'),
    path('auth/pin/verify/', PinVerifyView.as_view(), name='pin_verify'),

    # Biométrie (empreinte digitale)
    path('auth/biometric/register/', BiometricRegisterView.as_view(), name='biometric_register'),
    path('auth/biometric/login/', BiometricLoginView.as_view(), name='biometric_login'),
    path('auth/biometric/devices/', BiometricDeviceListView.as_view(), name='biometric_devices'),

    # Commission rates
    path('commissions/', CommissionInfoView.as_view(), name='commissions'),

    # Health check
    path('health/', HealthCheckView.as_view(), name='health'),

    # Router URLs (transactions, puces, etc.)
    path('', include(router.urls)),
]
