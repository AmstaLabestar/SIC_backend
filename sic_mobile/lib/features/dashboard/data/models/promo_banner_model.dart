import '../../domain/entities/promo_banner.dart';

class PromoBannerModel extends PromoBanner {
  const PromoBannerModel({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.ctaLabel,
    required super.ctaRoute,
    required super.imageAsset,
  });

  factory PromoBannerModel.fromJson(Map<String, dynamic> json) {
    return PromoBannerModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      ctaLabel: json['cta_label'] as String,
      ctaRoute: json['cta_route'] as String,
      imageAsset: json['image_asset'] as String? ?? '',
    );
  }

  factory PromoBannerModel.mock() {
    return const PromoBannerModel(
      id: 'banner_001',
      title: 'Gerez votre argent\nen toute simplicite',
      subtitle: 'Securise, rapide et toujours\na portee de main.',
      ctaLabel: 'En savoir plus',
      ctaRoute: '/info/sic',
      imageAsset: 'assets/images/banner_finance.png',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'cta_label': ctaLabel,
      'cta_route': ctaRoute,
      'image_asset': imageAsset,
    };
  }
}
