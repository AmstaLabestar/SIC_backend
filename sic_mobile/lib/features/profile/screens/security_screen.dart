import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/services/biometric_service.dart';
import 'package:sic_mobile/core/services/storage_service.dart';
import 'package:sic_mobile/data/providers/app_providers.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';

/// Security Settings Screen
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final BiometricService _biometricService = BiometricService();
  final StorageService _storageService = StorageService();

  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _pinSetup = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricsAvailable = await _biometricService.isBiometricAvailable();
    final biometricsEnabled = await _storageService.isBiometricsEnabled;
    final pinSetup = await _storageService.isPinSetup;

    if (!mounted) return;
    setState(() {
      _biometricsAvailable = biometricsAvailable;
      _biometricsEnabled = biometricsEnabled;
      _pinSetup = pinSetup;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value && !_biometricsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La biométrie n\'est pas disponible sur cet appareil'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (value) {
      // Verify biometrics before enabling
      final result = await _biometricService.authenticate(
        reason: 'Authentifiez-vous pour activer les empreintes digitales',
      );

      if (!result.isSuccess) {
        return;
      }
    }

    await _storageService.setBiometricsEnabled(value);
    setState(() => _biometricsEnabled = value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Empreinte digitale activée' : 'Empreinte digitale désactivée',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(SicTheme.spaceMd),
              children: [
                // Security header
                SicCard(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: SicTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Centre de sécurité',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Gérez vos paramètres de sécurité',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // PIN Section
                Text(
                  'Code PIN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: SicTheme.spaceSm),
                SicCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                          ),
                          child: const Icon(Icons.pin, color: Colors.blue),
                        ),
                        title: const Text('Code PIN'),
                        subtitle: Text(_pinSetup ? 'Configuré' : 'Non configuré'),
                        trailing: Switch(
                          value: _pinSetup,
                          onChanged: _pinSetup
                              ? null
                              : (value) => context.push('/auth/pin-setup'),
                        ),
                      ),
                      if (!_pinSetup) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(SicTheme.spaceSm),
                          child: Text(
                            'Le code PIN est requis pour valider les transactions importantes.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Biometrics Section
                Text(
                  'Authentification biométrique',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: SicTheme.spaceSm),
                SicCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.green),
                        ),
                        title: const Text('Empreinte digitale'),
                        subtitle: Text(
                          _biometricsAvailable
                              ? 'Utiliser l\'empreinte pour se connecter'
                              : 'Non disponible sur cet appareil',
                        ),
                        value: _biometricsEnabled,
                        onChanged: _biometricsAvailable ? _toggleBiometrics : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Devices Section
                Text(
                  'Appareils enregistrés',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: SicTheme.spaceSm),
                SicCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                          ),
                          child: const Icon(Icons.phone_android, color: Colors.purple),
                        ),
                        title: const Text('Cet appareil'),
                        subtitle: const Text('Appareil actuel'),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(SicTheme.spaceSm),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Maximum 3 appareils biométriques autorisés',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Session timeout
                Text(
                  'Délai de déconnexion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: SicTheme.spaceSm),
                SicCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                          ),
                          child: const Icon(Icons.timer, color: Colors.orange),
                        ),
                        title: const Text('Timeout de session'),
                        subtitle: const Text('5 minutes d\'inactivité'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Show timeout options
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SicTheme.spaceXl),

                // Info
                SicCard(
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Protection',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vos données sont protégées par un chiffrement de niveau bancaire. SIC ne stocke jamais votre mot de passe en clair.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SicTheme.spaceLg),
              ],
            ),
    );
  }
}