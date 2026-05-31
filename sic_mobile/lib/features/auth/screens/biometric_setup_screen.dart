import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/services/biometric_service.dart';
import 'package:sic_mobile/core/services/storage_service.dart';
import 'package:sic_mobile/shared/widgets/pin_pad.dart';

/// Biometric Setup Screen
class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  final BiometricService _biometricService = BiometricService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  bool _isSetup = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable && mounted) {
      setState(() {
        _errorMessage = 'La biométrie n\'est pas disponible sur cet appareil';
        _isSetup = true; // Skip this step
      });
    }
  }

  Future<void> _setupBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Authenticate with biometrics
      final result = await _biometricService.authenticate(
        reason: 'Authentifiez-vous pour configurer l\'empreinte digitale',
      );

      if (!result.isSuccess && mounted) {
        setState(() {
          _errorMessage = result.error ?? 'Erreur d\'authentification';
          _isLoading = false;
        });
        return;
      }

      // Generate device key pair
      final keyPair = await _biometricService.generateKeyPair();

      // Save biometric settings
      await _storageService.setBiometricsEnabled(true);

      if (mounted) {
        setState(() {
          _isSetup = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration biométrique réussie !'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la configuration';
          _isLoading = false;
        });
      }
    }
  }

  void _skipBiometricSetup() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Biométrique'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SicTheme.spaceLg),
          child: Column(
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const SizedBox(height: SicTheme.spaceLg),

              // Title
              Text(
                'Authentification par empreinte',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: SicTheme.spaceSm),

              // Description
              Text(
                'Utilisez votre empreinte digitale pour vous connecter rapidement et en toute sécurité à votre compte SIC.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: SicTheme.spaceLg),

              // Error message
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(SicTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SicTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: SicTheme.spaceSm),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Setup button
              if (!_isSetup) ...[
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _setupBiometric,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(_isLoading ? 'Configuration...' : 'Configurer'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),

                const SizedBox(height: SicTheme.spaceMd),

                // Skip button
                TextButton(
                  onPressed: _skipBiometricSetup,
                  child: const Text('Passer pour l\'instant'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _skipBiometricSetup,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuer'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],

              const SizedBox(height: SicTheme.spaceLg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Biometric Login Screen
class BiometricLoginScreen extends ConsumerStatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  ConsumerState<BiometricLoginScreen> createState() =>
      _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends ConsumerState<BiometricLoginScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String _errorMessage = '';

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    final result = await _biometricService.authenticate(
      reason: 'Authentifiez-vous pour accéder à SIC Mobile',
    );

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (result.isSuccess) {
      // Navigate to home
      context.go('/home');
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Erreur d\'authentification';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SicTheme.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: SicTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 48,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: SicTheme.spaceLg),

              // Title
              Text(
                'Connexion biométrique',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: SicTheme.spaceSm),

              // Description
              Text(
                'Touchez le bouton pour vous authentifier',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),

              const SizedBox(height: SicTheme.spaceXl),

              // Error
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(SicTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SicTheme.radiusMd),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: SicTheme.spaceLg),

              // Authenticate button
              ElevatedButton.icon(
                onPressed: _isAuthenticating ? null : _authenticate,
                icon: _isAuthenticating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(_isAuthenticating ? 'Authentification...' : 'S\'authentifier'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 52),
                ),
              ),

              const SizedBox(height: SicTheme.spaceLg),

              // Use password instead
              TextButton(
                onPressed: () => context.go('/auth/login'),
                child: const Text('Utiliser le mot de passe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}