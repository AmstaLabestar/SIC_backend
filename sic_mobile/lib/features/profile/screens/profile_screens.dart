import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';

/// Profile Screen
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Agent? _agent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final repo = SicRepository();
    final agent = await repo.getProfile();
    if (!mounted) return;
    setState(() {
      _agent = agent;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = SicRepository();
      await repo.logout();
      if (!mounted) return;
      context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(SicTheme.spaceMd),
                children: [
                  // Profile Header
                  SicCard(
                    child: Column(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            _agent?.initials ?? 'A',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: SicTheme.spaceMd),

                        // Name
                        Text(
                          _agent?.displayName ?? 'Agent',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 4),

                        // Phone
                        Text(
                          _agent?.phoneNumber ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: SicTheme.spaceSm),

                        // KYC Status
                        SicChip(
                          label: Formatters.kycStatusLabel(
                              _agent?.kycStatus ?? 'PENDING'),
                          backgroundColor: Color(Formatters.kycStatusColor(
                                  _agent?.kycStatus ?? 'PENDING'))
                              .withValues(alpha: 0.1),
                          textColor: Color(Formatters.kycStatusColor(
                              _agent?.kycStatus ?? 'PENDING')),
                          icon: _agent?.isKycApproved
                              ? Icons.verified
                              : Icons.pending,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SicTheme.spaceLg),

                  // Account Info
                  Text(
                    'Informations du compte',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),

                  const SizedBox(height: SicTheme.spaceSm),

                  SicCard(
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.person_outline,
                          'Nom d\'utilisateur',
                          _agent?.username ?? '-',
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Email',
                          _agent?.email ?? '-',
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.phone_android,
                          'Téléphone',
                          _agent?.phoneNumber ?? '-',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SicTheme.spaceLg),

                  // Security
                  Text(
                    'Sécurité',
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
                              borderRadius:
                                  BorderRadius.circular(SicTheme.radiusSm),
                            ),
                            child: const Icon(Icons.pin, color: Colors.blue),
                          ),
                          title: const Text('Code PIN'),
                          subtitle: const Text('Configurer ou modifier'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/profile/security'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(SicTheme.radiusSm),
                            ),
                            child:
                                const Icon(Icons.fingerprint, color: Colors.green),
                          ),
                          title: const Text('Sécurité'),
                          subtitle: const Text('Empreinte digitale et appareils'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/profile/security'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SicTheme.spaceLg),

                  // KYC
                  if (_agent?.isKycPending == true ||
                      _agent?.isKycRejected == true) ...[
                    Text(
                      'Vérification KYC',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),

                    const SizedBox(height: SicTheme.spaceSm),

                    SicCard(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _agent?.isKycRejected == true
                                    ? Icons.error_outline
                                    : Icons.pending,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _agent?.isKycRejected == true
                                          ? 'KYC Rejeté'
                                          : 'KYC en attente',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      _agent?.isKycRejected == true
                                          ? 'Veuillez resubmettre vos documents'
                                          : 'Votre dossier est en cours de vérification',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_agent?.isKycRejected == true) ...[
                            const SizedBox(height: SicTheme.spaceMd),
                            ElevatedButton(
                              onPressed: () {
                                context.push('/profile/kyc');
                              },
                              child: const Text('Resubmettre'),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: SicTheme.spaceLg),
                  ],

                  // Logout
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: SicTheme.spaceXl),

                  // Version
                  Center(
                    child: Text(
                      'Version 1.0.0',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  const SizedBox(height: SicTheme.spaceLg),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SicTheme.spaceSm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Notifications Screen
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: SicEmptyState(
        icon: Icons.notifications_none,
        title: 'Aucune notification',
        subtitle: 'Vos notifications apparaîtront ici',
      ),
    );
  }
}