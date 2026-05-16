from django.contrib import admin
from .models import Agent, Puce, Transaction, CompensationDetail

@admin.register(Agent)
class AgentAdmin(admin.ModelAdmin):
    list_display = ('id', 'first_name', 'last_name', 'phone_number', 'kyc_status', 'is_suspended')
    search_fields = ('phone_number', 'first_name', 'last_name')
    list_filter = ('kyc_status', 'is_suspended')

@admin.register(Puce)
class PuceAdmin(admin.ModelAdmin):
    list_display = ('operator', 'phone_number', 'balance', 'agent', 'is_active')
    search_fields = ('phone_number', 'agent__phone_number')
    list_filter = ('operator', 'is_active')

@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('id', 'type', 'amount', 'status', 'is_compensated', 'created_at')
    search_fields = ('id', 'agent__phone_number')
    list_filter = ('type', 'status', 'is_compensated')

@admin.register(CompensationDetail)
class CompensationDetailAdmin(admin.ModelAdmin):
    list_display = ('transaction', 'puce', 'amount_deducted', 'status', 'cinetpay_ref')
    search_fields = ('cinetpay_ref', 'transaction__id')
    list_filter = ('status',)
