from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('admin/', admin.site.urls),
    # Swagger UI URLs
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    
    path('api/', include('api.urls')),
    # Metriques Prometheus -> /metrics (a restreindre au reseau interne en prod).
    path('', include('django_prometheus.urls')),
    path('', include('dashboard.urls')),
]
