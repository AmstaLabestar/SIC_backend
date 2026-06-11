import 'package:equatable/equatable.dart';

/// Banniere promotionnelle affichee sur le dashboard.
///
/// En Phase 2 le contenu est mocke ; en Phase 3+ il proviendra de l'API
/// (`GET /dashboard/banners/`).
class PromoBanner extends Equatable {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.imageAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String ctaRoute;
  final String imageAsset;

  @override
  List<Object?> get props => [id, title, subtitle, ctaLabel, ctaRoute, imageAsset];
}
