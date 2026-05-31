"""
Migration: Ajout du code PIN et du modèle BiometricDevice
"""
from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0005_rename_chip_compensationdetail_puce_alter_puce_agent'),
    ]

    operations = [
        # Ajout des champs PIN à Agent
        migrations.AddField(
            model_name='agent',
            name='pin_code',
            field=models.CharField(blank=True, max_length=128, null=True),
        ),
        migrations.AddField(
            model_name='agent',
            name='pin_attempts',
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name='agent',
            name='pin_locked_until',
            field=models.DateTimeField(blank=True, null=True),
        ),

        # Création du modèle BiometricDevice
        migrations.CreateModel(
            name='BiometricDevice',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('device_id', models.CharField(max_length=255, unique=True)),
                ('device_name', models.CharField(blank=True, default='', max_length=100)),
                ('public_key', models.TextField(help_text='Clé publique du device pour vérification de signature')),
                ('is_active', models.BooleanField(default=True)),
                ('last_used_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('agent', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='biometric_devices', to='core.agent')),
            ],
            options={
                'unique_together': {('agent', 'device_id')},
            },
        ),
    ]
