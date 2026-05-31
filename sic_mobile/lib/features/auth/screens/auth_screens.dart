import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/config/constants.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';

/// Splash Screen
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final repo = SicRepository();
    final isLoggedIn = repo.isLoggedIn;

    if (isLoggedIn) {
      // Check if PIN is setup
      final hasPin = await _checkPinSetup();
      if (hasPin) {
        context.go('/auth/login');
      } else {
        context.go('/auth/pin-setup');
      }
    } else {
      context.go('/auth/login');
    }
  }

  Future<bool> _checkPinSetup() async {
    // Check if PIN is already setup
    return false; // TODO: Check from storage
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: SicTheme.primaryGradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(SicTheme.radiusXl),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: SicTheme.spaceLg),
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: SicTheme.spaceSm),
                      Text(
                        'La fintech qui vous ressemble',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                      ),
                      const SizedBox(height: SicTheme.spaceXxl),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Login Screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final repo = SicRepository();
    final result = await repo.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // Check if PIN is setup
      // Navigate based on KYC status
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur de connexion'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SicTheme.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: SicTheme.spaceXxl),

                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: SicTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(SicTheme.radiusLg),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.account_balance_wallet,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Title
                Text(
                  'Bienvenue !',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SicTheme.spaceSm),
                Text(
                  'Connectez-vous pour accéder à votre espace',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: SicTheme.spaceXxl),

                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom d\'utilisateur',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre nom d\'utilisateur';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: SicTheme.spaceMd),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: SicTheme.spaceMd),

                // Remember me
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() => _rememberMe = value ?? false);
                      },
                    ),
                    const Text('Se souvenir de moi'),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: Forgot password
                      },
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ],
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Se connecter'),
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pas encore de compte ? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push('/auth/register'),
                      child: const Text('S\'inscrire'),
                    ),
                  ],
                ),

                const SizedBox(height: SicTheme.spaceLg),

                // Biometric login
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Biometric login
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configuration biométrique requise'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Se connecter avec empreintes'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PIN Setup Screen
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onPinComplete(String pin) {
    if (!_isConfirming) {
      setState(() {
        _pin = pin;
        _isConfirming = true;
      });
    } else {
      _confirmPin = pin;
      _setupPin();
    }
  }

  Future<void> _setupPin() async {
    if (_pin != _confirmPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Les codes PIN ne correspondent pas'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() {
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final repo = SicRepository();
    final result = await repo.setupPin(
      password: _passwordController.text,
      pin: _pin,
      pinConfirm: _confirmPin,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isConfirming ? 'Confirmez le code PIN' : 'Créer un code PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SicTheme.spaceLg),
          child: Column(
            children: [
              const Spacer(),

              // Explanation
              Text(
                _isConfirming
                    ? 'Confirmez votre code PIN à 4 chiffres'
                    : 'Créez un code PIN à 4 chiffres pour sécuriser vos transactions',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: SicTheme.spaceXxl),

              // PIN Pad
              Expanded(
                child: Center(
                  child: PinPadWidget(
                    pinLength: 4,
                    onPinComplete: _onPinComplete,
                    isLoading: _isLoading,
                  ),
                ),
              ),

              // Password field (for initial setup)
              if (!_isConfirming) ...[
                const SizedBox(height: SicTheme.spaceMd),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmez avec votre mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
              ],

              const SizedBox(height: SicTheme.spaceLg),

              // Skip for now
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Passer pour l\'instant'),
              ),

              const SizedBox(height: SicTheme.spaceLg),
            ],
          ),
        ),
      ),
    );
  }
}

/// PIN Pad Widget (simplified version)
class PinPadWidget extends StatefulWidget {
  final int pinLength;
  final void Function(String) onPinComplete;
  final bool isLoading;

  const PinPadWidget({
    super.key,
    this.pinLength = 4,
    required this.onPinComplete,
    this.isLoading = false,
  });

  @override
  State<PinPadWidget> createState() => _PinPadWidgetState();
}

class _PinPadWidgetState extends State<PinPadWidget> {
  String _pin = '';

  void _onKeyTap(String key) {
    if (widget.isLoading) return;

    if (key == 'delete') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
        });
      }
    } else {
      if (_pin.length < widget.pinLength) {
        setState(() {
          _pin += key;
        });
        if (_pin.length == widget.pinLength) {
          widget.onPinComplete(_pin);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _pin.length ? primaryColor : Colors.transparent,
                border: Border.all(color: primaryColor, width: 2),
              ),
            );
          }),
        ),

        const SizedBox(height: 40),

        // Keypad
        Column(
          children: [
            _buildRow(['1', '2', '3'], primaryColor),
            const SizedBox(height: 12),
            _buildRow(['4', '5', '6'], primaryColor),
            const SizedBox(height: 12),
            _buildRow(['7', '8', '9'], primaryColor),
            const SizedBox(height: 12),
            _buildRow(['', '0', 'delete'], primaryColor),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 80, height: 56);
        return _buildKey(key, primaryColor);
      }).toList(),
    );
  }

  Widget _buildKey(String key, Color primaryColor) {
    return Container(
      width: 80,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? SicTheme.surfaceLightDark
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(SicTheme.radiusMd),
        child: InkWell(
          onTap: widget.isLoading ? null : () => _onKeyTap(key),
          borderRadius: BorderRadius.circular(SicTheme.radiusMd),
          child: Center(
            child: key == 'delete'
                ? Icon(Icons.backspace_outlined, color: primaryColor)
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}