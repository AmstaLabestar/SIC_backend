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
    TransactionViewSet, PuceViewSet, AgentProfileView, AccountLimitsView,
    RegisterView, OtpSendView, CommissionInfoView, HealthCheckView,
    CustomTokenObtainPairView, DeviceVerifyView, LogoutView,
    PasswordResetRequestView, PasswordResetConfirmView,
    PinSetupView, PinVerifyView,
    BiometricRegisterView, BiometricLoginView, BiometricDeviceListView
)

router = DefaultRouter()
router.register(r'transactions', TransactionViewSet, basename='transaction')
router.register(r'puces', PuceViewSet, basename='puce')

urlpatterns = [
    # Authentication
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/otp/send/', OtpSendView.as_view(), name='otp_send'),
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/device/verify/', DeviceVerifyView.as_view(), name='device_verify'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/verify/', TokenVerifyView.as_view(), name='token_verify'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('auth/password/reset/request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('auth/password/reset/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('auth/profile/', AgentProfileView.as_view(), name='agent_profile'),
    path('auth/limits/', AccountLimitsView.as_view(), name='account_limits'),

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
