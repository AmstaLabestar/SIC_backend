from django.urls import path
from . import views

app_name = 'dashboard'

urlpatterns = [
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('', views.home, name='dashboard_home'),
    path('agents/', views.agents, name='agents'),
    path('agents/<uuid:agent_id>/<str:action>/', views.agent_kyc_action, name='agent_kyc_action'),
    path('transactions/', views.transactions, name='dashboard_transactions'),
    path('transactions/<uuid:tx_id>/', views.transaction_detail, name='transaction_detail'),
    path('transactions/<str:tx_type>/', views.transactions, name='transactions_type'),
    
    # Reports
    path('reports/', views.report_list, name='report_list'),
    path('reports/create/', views.report_create, name='report_create'),
    path('reports/<uuid:report_id>/', views.report_detail, name='report_detail'),
    path('reports/<uuid:report_id>/edit/', views.report_create, name='report_edit'),
    path('reports/<uuid:report_id>/delete/', views.report_delete, name='report_delete'),
    
    # Audit Logs
    path('audit/logs/', views.activity_logs, name='activity_logs'),
]
