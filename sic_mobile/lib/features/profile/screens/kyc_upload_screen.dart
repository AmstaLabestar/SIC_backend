import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/providers/app_providers.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';

/// KYC Upload Screen
class KycUploadScreen extends ConsumerStatefulWidget {
  const KycUploadScreen({super.key});

  @override
  ConsumerState<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends ConsumerState<KycUploadScreen> {
  String? _frontIdCard;
  String? _backIdCard;
  String? _selfie;
  bool _isUploading = false;

  bool get _allDocumentsUploaded =>
      _frontIdCard != null && _backIdCard != null && _selfie != null;

  Future<void> _pickImage(String type) async {
    // Simulate image picking
    setState(() {
      switch (type) {
        case 'front':
          _frontIdCard = 'front_id_card.jpg';
          break;
        case 'back':
          _backIdCard = 'back_id_card.jpg';
          break;
        case 'selfie':
          _selfie = 'selfie.jpg';
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type uploaded'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _submitDocuments() async {
    if (!_allDocumentsUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez importer tous les documents'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    // Simulate upload
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isUploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Documents soumis avec succès !'),
        backgroundColor: Colors.green,
      ),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification KYC'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SicTheme.spaceMd),
        children: [
          // Info Card
          SicCard(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Column(
              children: [
                Icon(
                  Icons.verified_user,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: SicTheme.spaceMd),
                Text(
                  'Vérification d\'identité',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: SicTheme.spaceSm),
                Text(
                  'Pour valider votre compte, veuillez soumettre les documents suivants :',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: SicTheme.spaceLg),

          // Document requirements
          _buildDocumentCard(
            title: 'Carte d\'identité (Recto)',
            description: 'Photo claire du recto de votre carte d\'identité nationale',
            icon: Icons.badge,
            color: Colors.blue,
            isUploaded: _frontIdCard != null,
            onTap: () => _pickImage('front'),
          ),

          _buildDocumentCard(
            title: 'Carte d\'identité (Verso)',
            description: 'Photo claire du verso de votre carte d\'identité nationale',
            icon: Icons.badge,
            color: Colors.green,
            isUploaded: _backIdCard != null,
            onTap: () => _pickImage('back'),
          ),

          _buildDocumentCard(
            title: 'Selfie avec pièce d\'identité',
            description: 'Prenez un selfie en tenant votre pièce d\'identité',
            icon: Icons.camera_alt,
            color: Colors.orange,
            isUploaded: _selfie != null,
            onTap: () => _pickImage('selfie'),
          ),

          const SizedBox(height: SicTheme.spaceLg),

          // Requirements
          SicCard(
            backgroundColor: Colors.amber.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Exigences',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Les documents doivent être lisibles et non expirés\n'
                  '• La photo doit être récente (moins de 6 mois)\n'
                  '• Le selfie doit montrer clairement votre visage\n'
                  '• Formats acceptés: JPG, PNG (max 5MB)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(height: SicTheme.spaceXl),

          // Submit button
          ElevatedButton(
            onPressed: _allDocumentsUploaded && !_isUploading ? _submitDocuments : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Soumettre les documents'),
          ),

          const SizedBox(height: SicTheme.spaceLg),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: SicTheme.spaceMd),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? SicTheme.surfaceDark
            : Colors.white,
        borderRadius: BorderRadius.circular(SicTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SicTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(SicTheme.spaceMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SicTheme.radiusMd),
              border: Border.all(
                color: isUploaded
                    ? Colors.green
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isUploaded
                        ? Colors.green.withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                  ),
                  child: Icon(
                    isUploaded ? Icons.check_circle : icon,
                    color: isUploaded ? Colors.green : color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: SicTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (isUploaded) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OK',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  isUploaded ? Icons.check : Icons.camera_alt,
                  color: isUploaded ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}