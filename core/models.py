import uuid
from django.db import models
from django.contrib.auth.models import User
from django.contrib.auth.hashers import make_password, check_password


class Agent(models.Model):
    # Type de compte : AGENT (PDV : float multi-puces, compensation, commission)
    # ou CLIENT (grand public : transfert/recharge, pas de puce). Defaut AGENT
    # pour compatibilite ascendante (toutes les lignes existantes sont des agents).
    ACCOUNT_AGENT = 'AGENT'
    ACCOUNT_CLIENT = 'CLIENT'
    ACCOUNT_TYPE_CHOICES = [
        (ACCOUNT_AGENT, 'Agent'),
        (ACCOUNT_CLIENT, 'Client'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='agent_profile')
    account_type = models.CharField(
        max_length=10, choices=ACCOUNT_TYPE_CHOICES, default=ACCOUNT_AGENT
    )
    phone_number = models.CharField(max_length=20, unique=True)
    first_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)

    # Code marchand (numero de caisse) attribue par l'operateur a l'agent PDV,
    # ex. Orange *144*3*<merchant_code>*montant#. Declare a l'inscription (lot D1),
    # valide par l'admin via le flux KYC. Vide pour un CLIENT (pas de caisse).
    merchant_code = models.CharField(max_length=50, blank=True, default='')

    # KYC Info — documents uploadés (lot C3). Conservent le suffixe `_url` par
    # compat historique mais sont désormais des FileField (le `.url` donne le
    # chemin sous MEDIA_URL). FileField (pas ImageField) : pas de dépendance Pillow.
    id_card_front_url = models.FileField(upload_to='kyc/', null=True, blank=True)
    id_card_back_url = models.FileField(upload_to='kyc/', null=True, blank=True)
    selfie_url = models.FileField(upload_to='kyc/', null=True, blank=True)
    # PENDING (starter, rien soumis) · SUBMITTED (dossier en revue) · APPROVED · REJECTED
    kyc_status = models.CharField(max_length=20, default='PENDING')
    # Palier de confiance KYC pilotant les plafonds (cf api/services/limits.py) :
    # 0 = Starter (sans pièce), 1 = pièce vérifiée, 2 = complet (pièce+selfie).
    # Défaut 0 ; les comptes APPROVED existants sont passés à 2 par migration.
    kyc_tier = models.PositiveSmallIntegerField(default=0)
    # Suivi de soumission KYC (lot C3) : palier demandé, date, motif de rejet.
    kyc_requested_tier = models.PositiveSmallIntegerField(null=True, blank=True)
    kyc_submitted_at = models.DateTimeField(null=True, blank=True)
    kyc_rejection_reason = models.CharField(max_length=255, blank=True, default='')

    # Code secret (PIN hashé)
    pin_code = models.CharField(max_length=128, null=True, blank=True)
    pin_attempts = models.IntegerField(default=0)
    pin_locked_until = models.DateTimeField(null=True, blank=True)

    is_suspended = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def set_pin(self, raw_pin):
        """Hash et stocke le PIN."""
        self.pin_code = make_password(raw_pin)
        self.pin_attempts = 0
        self.pin_locked_until = None
        self.save()

    def check_pin(self, raw_pin):
        """Vérifie le PIN."""
        return check_password(raw_pin, self.pin_code)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.phone_number})"


class BiometricDevice(models.Model):
    """
    Appareil enregistré pour l'authentification biométrique.
    Le scan d'empreinte se fait côté mobile, l'API valide le device token.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE, related_name='biometric_devices')
    device_id = models.CharField(max_length=255, unique=True)
    device_name = models.CharField(max_length=100, blank=True, default='')
    public_key = models.TextField(help_text="Clé publique du device pour vérification de signature")
    is_active = models.BooleanField(default=True)
    last_used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('agent', 'device_id')

    def __str__(self):
        return f"{self.agent.first_name} - {self.device_name or self.device_id[:12]}"


class TrustedDevice(models.Model):
    """Appareil de confiance lié à un compte (lot A4 — device binding).

    Défense contre le SIM-swap : même avec les bons identifiants, un **nouvel**
    appareil doit être vérifié par OTP email (canal distinct du numéro) avant de
    pouvoir se connecter. Le premier appareil d'un compte est approuvé
    automatiquement (enrôlement), les suivants exigent l'OTP.

    Distinct de `BiometricDevice` (qui porte une clé publique pour la signature) :
    un appareil peut être de confiance sans biométrie activée. Un appareil
    biométrique enrôlé est aussi marqué de confiance.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE, related_name='trusted_devices')
    device_id = models.CharField(max_length=255)
    device_name = models.CharField(max_length=100, blank=True, default='')
    last_used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('agent', 'device_id')

    def __str__(self):
        return f"{self.agent.first_name} - {self.device_name or self.device_id[:12]}"


class Puce(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE, related_name='puces')
    operator = models.CharField(max_length=50) # ORANGE, MOOV, TELECEL, MTN
    # Unicité globale : une puce = un compte float réel chez l'opérateur,
    # un numéro ne peut appartenir qu'à un seul agent (intégrité fintech).
    phone_number = models.CharField(max_length=20, unique=True)
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('agent', 'operator', 'phone_number')

    def __str__(self):
        return f"{self.operator} - {self.phone_number} ({self.balance} FCFA)"


class AlertConfig(models.Model):
    """
    Seuil d'alerte de solde bas, attache a une puce (float reel).

    Cree automatiquement a la creation d'une puce (signal post_save), puis
    parametrable par l'agent proprietaire. Le seuil garde un compte float
    precis : 1 puce = 1 alerte (granularite per-puce).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    puce = models.OneToOneField(
        Puce, on_delete=models.CASCADE, related_name='alert_config'
    )
    threshold = models.DecimalField(max_digits=12, decimal_places=2, default=50000)
    is_enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        etat = 'on' if self.is_enabled else 'off'
        return (
            f"Alerte {self.puce.operator} {self.puce.phone_number} "
            f"< {self.threshold} ({etat})"
        )


class Transaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE, related_name='transactions')
    type = models.CharField(max_length=50) # DEPOT, RETRAIT, TRANSFERT, SWAP
    status = models.CharField(max_length=20, default='PENDING') # PENDING, COMPLETED, FAILED
    
    target_operator = models.CharField(max_length=50)
    target_phone_number = models.CharField(max_length=50, null=True, blank=True)
    
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    # SIC preleve une commission unique par transaction (lot C4). L'agent ne
    # gagne rien via SIC ; son gain = volume sauve par la compensation (calcule
    # cote app a partir de is_compensated), pas un montant stocke ici.
    commission_sic = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    # Frais factures au client (compte CLIENT) ; bareme defini en piste D. Defaut 0.
    fee = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    is_compensated = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.type} - {self.amount} FCFA ({self.status})"


class CompensationDetail(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    transaction = models.ForeignKey(Transaction, on_delete=models.CASCADE, related_name='compensation_details')
    puce = models.ForeignKey(Puce, on_delete=models.CASCADE, related_name='compensation_details')
    
    amount_deducted = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=20, default='PENDING') # PENDING, SUCCESS, REFUNDED
    cinetpay_ref = models.CharField(max_length=100, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Comp {self.transaction.id} - {self.puce.operator} ({self.status})"


class Report(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=200)
    
    # Filtres
    date_range = models.CharField(max_length=50, default='ALL') # ALL, TODAY, THIS_WEEK, THIS_MONTH
    tx_type = models.CharField(max_length=50, default='ALL') # ALL, DEPOT, RETRAIT, TRANSFERT, SWAP
    operator = models.CharField(max_length=50, default='ALL') # ALL, Orange, Moov, MTN, Wave
    status = models.CharField(max_length=20, default='ALL') # ALL, COMPLETED, PENDING, FAILED
    
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reports', null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title


class ActivityLog(models.Model):
    LEVEL_CHOICES = (
        ('INFO', 'Information'),
        ('SUCCESS', 'Succès'),
        ('WARNING', 'Avertissement'),
        ('ERROR', 'Erreur'),
    )
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='activity_logs')
    agent = models.ForeignKey('Agent', on_delete=models.SET_NULL, null=True, blank=True, related_name='activity_logs')
    
    action = models.CharField(max_length=100)
    description = models.TextField()
    level = models.CharField(max_length=20, choices=LEVEL_CHOICES, default='INFO')
    
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    is_read = models.BooleanField(default=False) # For notifications
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.level}] {self.action} - {self.created_at.strftime('%Y-%m-%d %H:%M')}"


class EmailOtp(models.Model):
    """Code OTP envoyé par email (vérification à l'inscription, reset à venir).

    Canal volontairement interchangeable (email en v1 ; SMS/WhatsApp plus tard
    sans changer ce modèle). L'email prouve la possession de l'email, pas du
    numéro — la validation réelle de l'identité reste le KYC.
    """
    PURPOSE_REGISTER = 'register'
    PURPOSE_RESET = 'reset'
    PURPOSE_DEVICE = 'device'  # vérification d'un nouvel appareil (lot A4)
    MAX_ATTEMPTS = 5

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(db_index=True)
    code = models.CharField(max_length=6)
    purpose = models.CharField(max_length=20, default=PURPOSE_REGISTER)
    attempts = models.PositiveSmallIntegerField(default=0)
    is_used = models.BooleanField(default=False)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=['email', 'purpose', 'is_used'])]

    def is_valid(self):
        from django.utils import timezone
        return (
            not self.is_used
            and self.attempts < self.MAX_ATTEMPTS
            and self.expires_at > timezone.now()
        )

    def __str__(self):
        return f"OTP {self.purpose} {self.email} ({'used' if self.is_used else 'active'})"
