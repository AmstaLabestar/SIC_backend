"""
Service OTP par email (lot A2).

Génère, envoie et vérifie des codes à 6 chiffres. Canal email en v1 (backend
console en dev, SMTP via env en prod) — interchangeable vers SMS/WhatsApp plus
tard sans toucher les appelants.
"""
import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

from core.models import EmailOtp


def _ttl_minutes():
    return int(getattr(settings, 'OTP_TTL_MINUTES', 10))


def generate_and_send(email, purpose=EmailOtp.PURPOSE_REGISTER):
    """Crée un OTP pour [email], invalide les précédents, l'envoie par email.
    Retourne la durée de validité en secondes."""
    email = (email or '').strip().lower()
    code = f'{secrets.randbelow(1000000):06d}'
    ttl = _ttl_minutes()

    # Un seul OTP actif à la fois par (email, purpose).
    EmailOtp.objects.filter(
        email=email, purpose=purpose, is_used=False
    ).update(is_used=True)
    EmailOtp.objects.create(
        email=email,
        code=code,
        purpose=purpose,
        expires_at=timezone.now() + timedelta(minutes=ttl),
    )

    send_mail(
        subject='Votre code de vérification SIC',
        message=(
            f'Votre code de vérification SIC est : {code}\n'
            f'Il expire dans {ttl} minutes.\n\n'
            "Si vous n'êtes pas à l'origine de cette demande, ignorez ce message."
        ),
        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@sic.local'),
        recipient_list=[email],
        # Ne bloque pas l'inscription si l'envoi échoue (console en dev, SMTP
        # éventuellement indisponible) ; le code reste vérifiable côté serveur.
        fail_silently=True,
    )
    return ttl * 60


def verify(email, code, purpose=EmailOtp.PURPOSE_REGISTER):
    """Vérifie un code. Retourne (ok: bool, message: str | None). Consomme
    l'OTP en cas de succès ; incrémente le compteur de tentatives sinon."""
    email = (email or '').strip().lower()
    code = (code or '').strip()

    otp = (
        EmailOtp.objects.filter(email=email, purpose=purpose, is_used=False)
        .order_by('-created_at')
        .first()
    )
    if otp is None:
        return False, 'Aucun code en attente. Demandez un nouveau code.'
    if not otp.is_valid():
        return False, 'Code expiré. Demandez un nouveau code.'
    if otp.code != code:
        otp.attempts += 1
        otp.save(update_fields=['attempts'])
        remaining = max(0, EmailOtp.MAX_ATTEMPTS - otp.attempts)
        return False, f'Code incorrect. {remaining} tentative(s) restante(s).'

    otp.is_used = True
    otp.save(update_fields=['is_used'])
    return True, None
