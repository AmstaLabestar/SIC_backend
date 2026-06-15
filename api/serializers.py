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

    Identifiant de connexion (lot A3) : le **numéro de téléphone** est
    l'identifiant principal v1. Le client mobile envoie `phone_number` ; on le
    normalise puis on retrouve le compte correspondant. Le `username` reste
    accepté en repli (comptes existants, admin, démo) afin de ne rien casser.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Identifiant par téléphone (principal). Username devient optionnel.
        self.fields['phone_number'] = serializers.CharField(required=False)
        self.fields[self.username_field].required = False

    @staticmethod
    def _resolve_username(identifier):
        """Traduit un identifiant saisi (téléphone OU username) en username.

        Si l'identifiant ressemble à un numéro valide et correspond à un agent,
        on renvoie le username du compte lié. Sinon on renvoie l'identifiant tel
        quel (repli username) : `authenticate()` jugera de sa validité.
        """
        from api.services.compensation_engine import TransactionValidator
        try:
            national = TransactionValidator.validate_phone_number(identifier)
        except ValueError:
            return identifier
        agent = (Agent.objects
                 .filter(phone_number=national)
                 .select_related('user')
                 .first())
        return agent.user.username if agent else identifier

    def validate(self, attrs):
        identifier = (attrs.get('phone_number')
                      or attrs.get(self.username_field) or '').strip()
        if identifier:
            attrs[self.username_field] = self._resolve_username(identifier)
        attrs.pop('phone_number', None)
        return super().validate(attrs)

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # Custom claims
        agent = getattr(user, 'agent_profile', None)
        if agent:
            token['agent_id'] = str(agent.id)
            token['account_type'] = agent.account_type
            token['kyc_status'] = agent.kyc_status
            token['kyc_tier'] = agent.kyc_tier
            token['first_name'] = agent.first_name or ''
            token['phone_number'] = agent.phone_number
            token['has_pin'] = agent.pin_code is not None
        else:
            token['agent_id'] = None
            token['account_type'] = None
            token['kyc_status'] = None
            token['kyc_tier'] = None
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
        # Refuser les PIN triviaux (lot A6) : tout identiques / séquences.
        from api.services.pin_rules import weak_pin_reason
        reason = weak_pin_reason(value)
        if reason:
            raise serializers.ValidationError(reason)
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
        help_text='Numéro (Burkina +226, 8 chiffres ; ex: 70123456)'
    )
    first_name = serializers.CharField(required=False, max_length=100, allow_blank=True)
    last_name = serializers.CharField(required=False, max_length=100, allow_blank=True)
    # Type de compte choisi a l'inscription. Defaut AGENT (l'app mobile actuelle
    # est orientee agent ; le choix de role cote UI viendra avec le lot D1).
    account_type = serializers.ChoiceField(
        choices=Agent.ACCOUNT_TYPE_CHOICES,
        required=False,
        default=Agent.ACCOUNT_AGENT,
    )
    # Code marchand de l'agent (lot D1) : requis si account_type=AGENT, ignore
    # pour un CLIENT. Valide ensuite par l'admin via le flux KYC.
    merchant_code = serializers.CharField(
        required=False, allow_blank=True, default='', max_length=50)
    # Code OTP reçu par email, à vérifier avant la création du compte (lot A2).
    otp = serializers.CharField(write_only=True, required=True, max_length=6)
    # Appareil d'inscription (lot A4) : approuvé d'office comme appareil de
    # confiance puisque l'email vient d'être vérifié par OTP. Optionnel.
    device_id = serializers.CharField(
        write_only=True, required=False, allow_blank=True, max_length=255)
    device_name = serializers.CharField(
        write_only=True, required=False, allow_blank=True, default='', max_length=100)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm',
                  'phone_number', 'first_name', 'last_name', 'account_type',
                  'merchant_code', 'otp', 'device_id', 'device_name']

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
        """Valider le numéro (Burkina Faso +226 / Côte d'Ivoire +225)."""
        from api.services.compensation_engine import TransactionValidator

        # Pas d'opérateur à l'inscription : on accepte tout opérateur valide.
        try:
            national = TransactionValidator.validate_phone_number(value)
        except ValueError as e:
            raise serializers.ValidationError(str(e))

        # Vérifier si déjà utilisé (profil agent OU puce) sur le numéro normalisé.
        if (Agent.objects.filter(phone_number=national).exists()
                or Puce.objects.filter(phone_number=national).exists()):
            raise serializers.ValidationError("Ce numéro de téléphone est déjà utilisé.")

        return national

    def validate(self, attrs):
        """Le code marchand est obligatoire pour un AGENT (lot D1)."""
        account_type = attrs.get('account_type', Agent.ACCOUNT_AGENT)
        merchant_code = (attrs.get('merchant_code') or '').strip()
        if account_type == Agent.ACCOUNT_AGENT and not merchant_code:
            raise serializers.ValidationError({
                'merchant_code': "Le code marchand est obligatoire pour un agent."
            })
        attrs['merchant_code'] = merchant_code
        return attrs

    def create(self, validated_data):
        """Créer l'utilisateur et le profil agent."""
        # Extraire les données du téléphone
        phone_number = validated_data.pop('phone_number')
        first_name = validated_data.pop('first_name', '')
        last_name = validated_data.pop('last_name', '')
        account_type = validated_data.pop('account_type', Agent.ACCOUNT_AGENT)
        merchant_code = (validated_data.pop('merchant_code', '') or '').strip()
        # Un CLIENT n'a pas de caisse marchand : on ignore tout code fourni.
        if account_type != Agent.ACCOUNT_AGENT:
            merchant_code = ''
        otp_code = validated_data.pop('otp', '')
        device_id = (validated_data.pop('device_id', '') or '').strip()
        device_name = (validated_data.pop('device_name', '') or '').strip()
        validated_data.pop('password_confirm')  # Supprimer la confirmation

        # Vérifier l'OTP email AVANT de créer le compte (lot A2).
        from api.services.otp import verify as verify_otp
        ok, otp_msg = verify_otp(validated_data['email'], otp_code, 'register')
        if not ok:
            raise serializers.ValidationError({'otp': [otp_msg]})

        # Créer l'utilisateur
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=first_name,
            last_name=last_name
        )

        # Créer le profil (agent ou client)
        agent = Agent.objects.create(
            user=user,
            account_type=account_type,
            phone_number=phone_number,
            first_name=first_name,
            last_name=last_name,
            merchant_code=merchant_code,
            kyc_status='PENDING'  # Par défaut en attente de validation KYC
        )

        # Seul un AGENT possède des puces (float). Pour un agent, le numéro
        # d'inscription devient la première puce (opérateur déduit du préfixe).
        # Un CLIENT n'a pas de puce (modèle overlay : il paie via CinetPay).
        if account_type == Agent.ACCOUNT_AGENT:
            from api.services.compensation_engine import TransactionValidator
            operator = TransactionValidator.operator_for_number(phone_number)
            if operator:
                Puce.objects.create(
                    agent=agent,
                    operator=operator,
                    phone_number=phone_number,
                    balance=0,
                    is_active=True,
                )

        # Appareil d'inscription = appareil de confiance (lot A4). L'email a été
        # vérifié par OTP juste avant : pas besoin d'une 2e vérification au
        # premier login depuis ce téléphone.
        if device_id:
            from django.utils import timezone
            from core.models import TrustedDevice
            TrustedDevice.objects.get_or_create(
                agent=agent,
                device_id=device_id,
                defaults={'device_name': device_name, 'last_used_at': timezone.now()},
            )

        return user


class KycSubmitSerializer(serializers.Serializer):
    """
    Soumission d'un dossier KYC pour monter de palier (lot C3).

    - `requested_tier` : palier visé (1 = pièce vérifiée, 2 = complet).
    - documents en multipart : `id_card_front`, `id_card_back`, `selfie`.
    Les documents déjà fournis lors d'une soumission précédente sont réutilisés
    s'ils ne sont pas renvoyés.
    """
    requested_tier = serializers.IntegerField(min_value=1, max_value=2)
    id_card_front = serializers.FileField(required=False)
    id_card_back = serializers.FileField(required=False)
    selfie = serializers.FileField(required=False)

    def validate(self, attrs):
        agent = self.context.get('agent')
        tier = attrs['requested_tier']

        current = getattr(agent, 'kyc_tier', 0) or 0
        if tier <= current:
            raise serializers.ValidationError(
                f"Vous êtes déjà au palier {current}. Demandez un palier supérieur."
            )

        has_front = attrs.get('id_card_front') or (agent and agent.id_card_front_url)
        has_selfie = attrs.get('selfie') or (agent and agent.selfie_url)
        if tier >= 1 and not has_front:
            raise serializers.ValidationError(
                {'id_card_front': "Pièce d'identité (recto) requise."}
            )
        if tier >= 2 and not has_selfie:
            raise serializers.ValidationError(
                {'selfie': "Un selfie est requis pour le palier complet."}
            )
        return attrs


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
        help_text='Opérateur: ORANGE, MOOV, TELECEL, MTN'
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
        from api.services.compensation_engine import TransactionValidator
        operator = value.upper().strip()
        if operator not in TransactionValidator.VALID_OPERATORS:
            raise serializers.ValidationError(
                f"Opérateur invalide. Options: {', '.join(TransactionValidator.VALID_OPERATORS)}"
            )
        return operator

    def validate_target_phone_number(self, value):
        """Nettoyage simple ; la validation par opérateur se fait dans validate()."""
        return value.strip().replace(' ', '').replace('-', '')

    def validate(self, attrs):
        """Validation croisée numéro <-> opérateur (Burkina +226 / Côte d'Ivoire +225)."""
        from api.services.compensation_engine import TransactionValidator
        operator = attrs.get('target_operator')
        phone = attrs.get('target_phone_number')
        if operator and phone:
            try:
                attrs['target_phone_number'] = TransactionValidator.validate_phone_number(
                    phone, operator
                )
            except ValueError as e:
                raise serializers.ValidationError({'target_phone_number': str(e)})
        return attrs


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
        help_text='Opérateur: ORANGE, MOOV, TELECEL, MTN'
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
        from api.services.compensation_engine import TransactionValidator
        operator = value.upper().strip()
        if operator not in TransactionValidator.VALID_OPERATORS:
            raise serializers.ValidationError(
                f"Opérateur invalide. Options: {', '.join(TransactionValidator.VALID_OPERATORS)}"
            )
        return operator

    def validate_target_phone_number(self, value):
        return value.strip().replace(' ', '').replace('-', '')

    def validate(self, attrs):
        from api.services.compensation_engine import TransactionValidator
        operator = attrs.get('target_operator')
        phone = attrs.get('target_phone_number')
        if operator and phone:
            try:
                attrs['target_phone_number'] = TransactionValidator.validate_phone_number(
                    phone, operator
                )
            except ValueError as e:
                raise serializers.ValidationError({'target_phone_number': str(e)})
        return attrs


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
        # Le solde n'est jamais modifiable par l'agent (géré côté admin / topup).
        read_only_fields = ['balance']

    def validate(self, attrs):
        """Valider l'opérateur et le numéro (Burkina +226 / Côte d'Ivoire +225).

        Gère aussi la mise à jour partielle (PATCH) en retombant sur l'instance.
        """
        from api.services.compensation_engine import TransactionValidator

        operator = (attrs.get('operator')
                    or getattr(self.instance, 'operator', '') or '').upper()
        phone = (attrs.get('phone_number')
                 or getattr(self.instance, 'phone_number', ''))

        if operator and operator not in TransactionValidator.VALID_OPERATORS:
            raise serializers.ValidationError({
                'operator': f"Opérateur invalide. "
                            f"Options: {', '.join(TransactionValidator.VALID_OPERATORS)}"
            })

        if phone:
            try:
                national = TransactionValidator.validate_phone_number(
                    phone, operator or None
                )
            except ValueError as e:
                raise serializers.ValidationError({'phone_number': str(e)})
            phone = national
            attrs['phone_number'] = national

            # Unicité GLOBALE du numéro : une puce = un compte float réel chez
            # l'opérateur. Un même numéro ne peut appartenir qu'à un seul agent
            # (sinon un agrégateur de paiement créditerait/débiterait le mauvais
            # compte). On vérifie aussi les numéros d'inscription des agents.
            request = self.context.get('request')
            agent = getattr(getattr(request, 'user', None), 'agent_profile', None)

            other_puces = Puce.objects.filter(phone_number=national)
            if self.instance is not None:
                other_puces = other_puces.exclude(pk=self.instance.pk)

            if agent is not None:
                used_by_other_agent = (
                    other_puces.exclude(agent=agent).exists()
                    or Agent.objects.filter(phone_number=national)
                    .exclude(pk=agent.pk)
                    .exists()
                )
                used_by_self = other_puces.filter(agent=agent).exists()
            else:
                used_by_other_agent = (
                    other_puces.exists()
                    or Agent.objects.filter(phone_number=national).exists()
                )
                used_by_self = False

            if used_by_other_agent:
                raise serializers.ValidationError({
                    'phone_number': "Ce numéro est déjà rattaché à un autre "
                                    "compte. Un numéro ne peut appartenir qu'à "
                                    "un seul agent."
                })
            if used_by_self:
                raise serializers.ValidationError({
                    'phone_number': "Vous avez déjà une puce avec ce numéro."
                })

        if 'operator' in attrs:
            attrs['operator'] = operator

        return attrs


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
            'id', 'username', 'email', 'account_type',
            'phone_number', 'first_name', 'last_name', 'merchant_code',
            'kyc_status', 'kyc_tier',
            'kyc_requested_tier', 'kyc_submitted_at', 'kyc_rejection_reason',
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
            'amount', 'commission_sic', 'fee',
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