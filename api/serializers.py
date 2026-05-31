"""
Serializers pour l'API SIC - Validation et sérialisation
"""
from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from core.models import Transaction, CompensationDetail, Puce, Agent, BiometricDevice


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    JWT custom qui ajoute des claims utiles dans le token.
    Évite un appel /profile/ à chaque requête côté mobile.
    """
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # Custom claims
        agent = getattr(user, 'agent_profile', None)
        if agent:
            token['agent_id'] = str(agent.id)
            token['kyc_status'] = agent.kyc_status
            token['first_name'] = agent.first_name or ''
            token['phone_number'] = agent.phone_number
            token['has_pin'] = agent.pin_code is not None
        else:
            token['agent_id'] = None
            token['kyc_status'] = None
            token['first_name'] = user.first_name or user.username
            token['has_pin'] = False

        return token


class PinSetupSerializer(serializers.Serializer):
    """
    Serializer pour définir/modifier le code PIN.
    Requiert le mot de passe actuel pour sécuriser l'opération.
    """
    password = serializers.CharField(
        required=True,
        write_only=True,
        help_text="Mot de passe actuel pour confirmer l'identité"
    )
    pin = serializers.CharField(
        required=True,
        min_length=4,
        max_length=6,
        help_text="Code PIN (4 à 6 chiffres)"
    )
    pin_confirm = serializers.CharField(
        required=True,
        min_length=4,
        max_length=6,
        help_text="Confirmer le code PIN"
    )

    def validate_pin(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Le PIN doit contenir uniquement des chiffres.")
        return value

    def validate(self, attrs):
        if attrs['pin'] != attrs['pin_confirm']:
            raise serializers.ValidationError({'pin_confirm': "Les codes PIN ne correspondent pas."})
        return attrs


class PinVerifySerializer(serializers.Serializer):
    """
    Serializer pour vérifier le code PIN.
    """
    pin = serializers.CharField(
        required=True,
        min_length=4,
        max_length=6,
        help_text="Code PIN à vérifier"
    )


class BiometricRegisterSerializer(serializers.Serializer):
    """
    Serializer pour enregistrer un appareil biométrique.
    L'app mobile envoie ces données après un scan d'empreinte réussi localement.
    """
    device_id = serializers.CharField(
        required=True,
        max_length=255,
        help_text="Identifiant unique de l'appareil"
    )
    device_name = serializers.CharField(
        required=False,
        max_length=100,
        default='',
        help_text="Nom de l'appareil (ex: iPhone 15 Pro)"
    )
    public_key = serializers.CharField(
        required=True,
        help_text="Clé publique générée par le device pour vérification de signature"
    )

    def validate_device_id(self, value):
        value = value.strip()
        if len(value) < 8:
            raise serializers.ValidationError("L'identifiant de l'appareil est trop court.")
        return value


class BiometricLoginSerializer(serializers.Serializer):
    """
    Serializer pour l'authentification biométrique.
    L'app mobile signe un challenge avec la clé privée après scan d'empreinte.
    """
    device_id = serializers.CharField(
        required=True,
        max_length=255,
        help_text="Identifiant de l'appareil enregistré"
    )
    signature = serializers.CharField(
        required=True,
        help_text="Signature du timestamp avec la clé privée du device"
    )
    timestamp = serializers.IntegerField(
        required=True,
        help_text="Timestamp Unix du moment de la signature (anti-replay)"
    )


class RegisterSerializer(serializers.ModelSerializer):
    """
    Serializer pour l'enregistrement d'un nouvel agent.

    Validation:
    - Username unique et longueur 3-150
    - Email unique et valide
    - Password complexe (via Django validators)
    - Numéro de téléphone unique et format valide
    """
    password = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
        help_text='Minimum 8 caractères, lettres et chiffres'
    )
    password_confirm = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
        help_text='Confirmer le mot de passe'
    )
    phone_number = serializers.CharField(
        required=True,
        max_length=20,
        help_text='Numéro de téléphone (ex: +224621234567)'
    )
    first_name = serializers.CharField(required=False, max_length=100, allow_blank=True)
    last_name = serializers.CharField(required=False, max_length=100, allow_blank=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm',
                  'phone_number', 'first_name', 'last_name']

    def validate_username(self, value):
        value = value.lower().strip()
        if len(value) < 3:
            raise serializers.ValidationError("Le nom d'utilisateur doit contenir au moins 3 caractères.")

        if not value.isalnum():
            raise serializers.ValidationError("Le nom d'utilisateur ne peut contenir que des lettres et des chiffres.")

        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur est déjà pris.")

        return value

    def validate_email(self, value):
        value = value.lower().strip()
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Cet email est déjà utilisé.")

        return value

    def validate_password(self, value):
        """Valider le mot de passe avec Django validators."""
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(list(e.messages))

        return value

    def validate_password_confirm(self, value):
        """Vérifier que les deux mots de passe correspondent."""
        password = self.initial_data.get('password', '')
        if value != password:
            raise serializers.ValidationError("Les mots de passe ne correspondent pas.")

        return value

    def validate_phone_number(self, value):
        """Valider le format du numéro de téléphone."""
        import re

        # Nettoyer le numéro
        phone = value.strip().replace(' ', '').replace('-', '')

        # Vérifier si déjà utilisé
        if Agent.objects.filter(phone_number=phone).exists():
            raise serializers.ValidationError("Ce numéro de téléphone est déjà utilisé.")

        # Pattern pour numéros Ouest-Africains ( indicatif +224, +226, +228, +229)
        pattern = r'^(\+224|\+226|\+228|\+229)?[0-9]{8,9}$'

        if not re.match(pattern, phone):
            raise serializers.ValidationError(
                "Format de numéro invalide. Utilisez le format international (ex: +224621234567)"
            )

        return phone

    def create(self, validated_data):
        """Créer l'utilisateur et le profil agent."""
        # Extraire les données du téléphone
        phone_number = validated_data.pop('phone_number')
        first_name = validated_data.pop('first_name', '')
        last_name = validated_data.pop('last_name', '')
        validated_data.pop('password_confirm')  # Supprimer la confirmation

        # Créer l'utilisateur
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=first_name,
            last_name=last_name
        )

        # Créer le profil agent
        Agent.objects.create(
            user=user,
            phone_number=phone_number,
            first_name=first_name,
            last_name=last_name,
            kyc_status='PENDING'  # Par défaut en attente de validation KYC
        )

        return user


class DepositSerializer(serializers.Serializer):
    """
    Serializer pour les dépôts.

    Validation:
    - Montant entre 100 et 5,000,000 FCFA
    - Opérateur valide
    - Numéro de téléphone valide
    """
    amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=100,
        max_value=5000000,
        required=True,
        help_text='Montant en FCFA (min: 100, max: 5,000,000)'
    )
    target_operator = serializers.CharField(
        max_length=50,
        required=True,
        help_text='Opérateur: ORANGE, MOOV, TELECEL, CORIS'
    )
    target_phone_number = serializers.CharField(
        max_length=50,
        required=True,
        help_text='Numéro de téléphone du destinataire'
    )

    def validate_amount(self, value):
        """Valider le montant."""
        from django.conf import settings

        if value < settings.MIN_TRANSACTION_AMOUNT:
            raise serializers.ValidationError(
                f"Montant minimum: {settings.MIN_TRANSACTION_AMOUNT} FCFA"
            )

        if value > settings.MAX_TRANSACTION_AMOUNT:
            raise serializers.ValidationError(
                f"Montant maximum: {settings.MAX_TRANSACTION_AMOUNT} FCFA"
            )

        return value

    def validate_target_operator(self, value):
        """Valider l'opérateur."""
        valid_operators = ['ORANGE', 'MOOV', 'TELECEL', 'CORIS']
        operator = value.upper().strip()

        if operator not in valid_operators:
            raise serializers.ValidationError(
                f"Opérateur invalide. Options: {', '.join(valid_operators)}"
            )

        return operator

    def validate_target_phone_number(self, value):
        """Valider le numéro de téléphone."""
        import re

        phone = value.strip().replace(' ', '').replace('-', '')

        # Pattern simple pour numéros Ouest-Africains
        pattern = r'^(\+224|\+226|\+228|\+229)?[0-9]{8,9}$'

        if not re.match(pattern, phone):
            raise serializers.ValidationError(
                "Format de numéro invalide (ex: +224621234567)"
            )

        return phone


class WithdrawSerializer(serializers.Serializer):
    """
    Serializer pour les retraits.

    Même validation que les dépôts.
    """
    amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=100,
        max_value=5000000,
        required=True,
        help_text='Montant en FCFA'
    )
    target_operator = serializers.CharField(
        max_length=50,
        required=True,
        help_text='Opérateur: ORANGE, MOOV, TELECEL, CORIS'
    )
    target_phone_number = serializers.CharField(
        max_length=50,
        required=True,
        help_text='Numéro de téléphone'
    )

    def validate_amount(self, value):
        from django.conf import settings
        if value < settings.MIN_TRANSACTION_AMOUNT:
            raise serializers.ValidationError(f"Montant minimum: {settings.MIN_TRANSACTION_AMOUNT} FCFA")
        if value > settings.MAX_TRANSACTION_AMOUNT:
            raise serializers.ValidationError(f"Montant maximum: {settings.MAX_TRANSACTION_AMOUNT} FCFA")
        return value

    def validate_target_operator(self, value):
        valid_operators = ['ORANGE', 'MOOV', 'TELECEL', 'CORIS']
        operator = value.upper().strip()
        if operator not in valid_operators:
            raise serializers.ValidationError(f"Opérateur invalide. Options: {', '.join(valid_operators)}")
        return operator

    def validate_target_phone_number(self, value):
        import re
        phone = value.strip().replace(' ', '').replace('-', '')
        pattern = r'^(\+224|\+226|\+228|\+229)?[0-9]{8,9}$'
        if not re.match(pattern, phone):
            raise serializers.ValidationError("Format de numéro invalide")
        return phone


class ConversionSerializer(serializers.Serializer):
    """
    Serializer pour les conversions entre puces.

    Validation:
    - Montant valide
    - Puce source et cible existants
    - Solde suffisant sur la puce source
    - Les deux puces appartiennent à l'agent
    """
    amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=100,
        max_value=5000000,
        required=True,
        help_text='Montant à convertir en FCFA'
    )
    source_puce_id = serializers.UUIDField(
        required=True,
        help_text='UUID de la puce source'
    )
    target_puce_id = serializers.UUIDField(
        required=True,
        help_text='UUID de la puce cible'
    )

    def validate_amount(self, value):
        from django.conf import settings
        if value < settings.MIN_TRANSACTION_AMOUNT:
            raise serializers.ValidationError(f"Montant minimum: {settings.MIN_TRANSACTION_AMOUNT} FCFA")
        if value > settings.MAX_TRANSACTION_AMOUNT:
            raise serializers.ValidationError(f"Montant maximum: {settings.MAX_TRANSACTION_AMOUNT} FCFA")
        return value

    def validate(self, attrs):
        """Validation croisée des puces."""
        from core.models import Puce

        user = self.context.get('request').user
        agent = getattr(user, 'agent_profile', None)

        if not agent:
            raise serializers.ValidationError("Profil agent non trouvé")

        source_id = attrs.get('source_puce_id')
        target_id = attrs.get('target_puce_id')

        # Vérifier que les IDs sont différents
        if source_id == target_id:
            raise serializers.ValidationError(
                "La puce source et cible doivent être différentes"
            )

        # Vérifier que les puces existent et appartiennent à l'agent
        try:
            source_puce = Puce.objects.get(id=source_id, agent=agent)
            attrs['source_puce'] = source_puce
        except Puce.DoesNotExist:
            raise serializers.ValidationError({
                'source_puce_id': "Puce source introuvable ou n'appartenant pas à votre compte"
            })

        try:
            target_puce = Puce.objects.get(id=target_id, agent=agent)
            attrs['target_puce'] = target_puce
        except Puce.DoesNotExist:
            raise serializers.ValidationError({
                'target_puce_id': "Puce cible introuvable ou n'appartenant pas à votre compte"
            })

        # Vérifier le solde
        if source_puce.balance < attrs['amount']:
            raise serializers.ValidationError({
                'amount': f"Solde insuffisant sur la puce {source_puce.operator}. "
                         f"Disponible: {source_puce.balance} FCFA"
            })

        return attrs


class PuceSerializer(serializers.ModelSerializer):
    """
    Serializer pour les puces SIM.
    """

    class Meta:
        model = Puce
        fields = ['id', 'operator', 'phone_number',
                  'balance', 'is_active', 'created_at', 'updated_at']


class AgentSerializer(serializers.ModelSerializer):
    """
    Serializer pour le profil agent.
    """
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    puces = PuceSerializer(many=True, read_only=True)

    class Meta:
        model = Agent
        fields = [
            'id', 'username', 'email',
            'phone_number', 'first_name', 'last_name',
            'kyc_status',
            'is_suspended', 'puces',
            'created_at', 'updated_at'
        ]


class CompensationDetailSerializer(serializers.ModelSerializer):
    """
    Serializer pour les détails de compensation.
    """
    puce_operator = serializers.CharField(source='puce.operator', read_only=True)
    puce_phone = serializers.CharField(source='puce.phone_number', read_only=True)

    class Meta:
        model = CompensationDetail
        fields = [
            'id', 'puce_operator', 'puce_phone',
            'amount_deducted', 'status',
            'cinetpay_ref', 'created_at'
        ]


class TransactionSerializer(serializers.ModelSerializer):
    """
    Serializer pour les transactions.
    """
    agent_name = serializers.SerializerMethodField()
    compensation_details = CompensationDetailSerializer(many=True, read_only=True)

    class Meta:
        model = Transaction
        fields = [
            'id', 'agent_name', 'type',
            'status',
            'target_operator', 'target_phone_number',
            'amount', 'commission_sic', 'agent_benefit',
            'is_compensated',
            'compensation_details',
            'created_at', 'updated_at'
        ]

    def get_agent_name(self, obj):
        if obj.agent:
            return f"{obj.agent.first_name or ''} {obj.agent.last_name or ''}".strip()
        return "N/A"


class TransactionSummarySerializer(serializers.Serializer):
    """
    Serializer pour le résumé des transactions (pour les dashboards/stats).
    """
    total_count = serializers.IntegerField()
    total_volume = serializers.DecimalField(max_digits=15, decimal_places=2)
    total_profit = serializers.DecimalField(max_digits=15, decimal_places=2)
    avg_amount = serializers.DecimalField(max_digits=15, decimal_places=2)
    completed_count = serializers.IntegerField()
    pending_count = serializers.IntegerField()
    failed_count = serializers.IntegerField()