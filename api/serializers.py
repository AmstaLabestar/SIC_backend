from rest_framework import serializers
from core.models import Transaction, CompensationDetail, Puce, Agent

class DepositSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=100)
    target_operator = serializers.CharField(max_length=50)
    target_phone_number = serializers.CharField(max_length=50)

class WithdrawSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=100)
    target_operator = serializers.CharField(max_length=50)
    target_phone_number = serializers.CharField(max_length=50)

class ConversionSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=100)
    source_puce_id = serializers.UUIDField()
    target_puce_id = serializers.UUIDField()

class TransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transaction
        fields = '__all__'

class PuceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Puce
        fields = ['id', 'operator', 'phone_number', 'balance', 'is_active', 'created_at']

class AgentSerializer(serializers.ModelSerializer):
    puces = PuceSerializer(many=True, read_only=True)
    
    class Meta:
        model = Agent
        fields = ['id', 'first_name', 'last_name', 'phone_number', 'kyc_status', 'is_suspended', 'puces']
