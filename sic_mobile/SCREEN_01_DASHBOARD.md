# SCREEN 01 — Dashboard Principal
## SIC Mobile · Phase 2 · Écran validé ✅

> Spec basée sur le mockup final validé par le client.
> Référence visuelle : `screen_dashboard_final.png`

---

## 1. VUE D'ENSEMBLE

| Propriété | Valeur |
|---|---|
| Route go_router | `/dashboard` |
| Fichier principal | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` |
| Type widget | `ConsumerWidget` (Riverpod) |
| Scroll principal | `SingleChildScrollView` + `RefreshIndicator` |
| Orientation | Portrait uniquement |
| Phase | 2 — mock data, prêt pour branchement API Django |

---

## 2. PALETTE OFFICIELLE SIC

```dart
// lib/core/constants/app_colors.dart
primary        : Color(0xFF1A3C6E)  // AppBar nav actif, bottom nav
primaryLight   : Color(0xFF2356A8)  // gradient hero, liens, retrait
primaryBg      : Color(0xFFEBF1FA)  // fond cards actions bleu
secondary      : Color(0xFF1B8C5E)  // dépôt, avatar, recharge
secondaryBg    : Color(0xFFE8F5EF)  // fond cards actions vert
success        : Color(0xFF22C97A)  // gain, statut OK, pip nav
warning        : Color(0xFFF59E0B)  // solde faible, fond card jaune
danger         : Color(0xFFEF4444)  // solde vide, badge alerte
background     : Color(0xFFF4F7FC)  // fond général app
surface        : Color(0xFFFFFFFF)  // fond cards SIM, actions
textPrimary    : Color(0xFF0D1B2A)  // titres, montants, labels
textSecondary  : Color(0xFF64748B)  // sous-titres, numéros SIM
textTertiary   : Color(0xFF94A3B8)  // nav inactif, placeholders
border         : Color(0xFFDCE6F0)  // bordures légères
```

---

## 3. STRUCTURE COMPLÈTE (de haut en bas)

```
┌──────────────────────────────────────────┐
│  HEADER (pas d'AppBar Flutter standard)  │
│  [●KM] Bonjour 👋              [💬][?][🔔🔴] │
│        Koné Moussa                        │
├──────────────────────────────────────────┤
│  HERO CARD — Solde Total                 │
│  Solde total · 3 SIM actives    [👁]     │
│  485 000  FCFA                           │
│  [↑ + 12 500 FCFA aujourd'hui]          │
├──────────────────────────────────────────┤
│  Mes SIM                      Gérer  >   │
│  ┌─────────────────┐ ┌─────────────────┐ │
│  │ [OM] Orange     │ │ [MV] Moov  ⚠️  │ │
│  │ 07•••234  [👁][⋮]│ │ 06•••891  [👁][⋮]│ │
│  │                 │ │                 │ │
│  │ 250 000 FCFA    │ │ 35 000 FCFA     │ │
│  │ ● Solde OK      │ │ ● Solde faible  │ │
│  │ [🕐 Historique] │ │ [🕐 Historique] │ │
│  │ [⊕ Recharger]  │ │ [⊕ Recharger]  │ │
│  └─────────────────┘ └─────────────────┘ │
├──────────────────────────────────────────┤
│  Actions rapides                         │
│  [↓Dépôt] [↑Retrait] [⇄Transfert] [📱Recharge] │
├──────────────────────────────────────────┤
│  BANNIÈRE PROMO (carousel)               │
│  "Gérez votre argent en toute simplicité"│
│  [En savoir plus >]        [illustration]│
│                    ● ○ ○ ○               │
├──────────────────────────────────────────┤
│  [🏠 Accueil ●] [📄 Transactions] [👤 Profil] │
└──────────────────────────────────────────┘
```

---

## 4. COMPOSANTS DÉTAILLÉS

---

### 4.1 Header (Custom — pas AppBar standard)

**Fichier :** widget inline dans `dashboard_screen.dart`
**Type :** `SliverAppBar` ou `Container` dans le `CustomScrollView`

| Élément | Spec détaillée |
|---|---|
| Fond | `AppColors.background` (#F4F7FC) — pas de gradient ici |
| Avatar | Cercle 52px, fond `#22C97A`, initiales "KM" blanc 16px bold |
| Salutation ligne 1 | "Bonjour 👋" — 14px regular `textSecondary` |
| Salutation ligne 2 | "Koné Moussa" — 20px bold `textPrimary` |
| Icône Chat | Carré arrondi 40px, fond blanc, bordure `border`, SVG bulle |
| Icône Aide | Même style, SVG `?` cerclé |
| Icône Cloche | Même style, badge rouge 8px `danger` en top-right |
| Padding | `EdgeInsets.symmetric(horizontal: 20, vertical: 16)` |

```dart
// Structure Header
Row(
  children: [
    // Avatar
    CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.success,
      child: Text('KM', style: AppTextStyles.avatarInitials),
    ),
    const SizedBox(width: 12),
    // Nom
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour 👋', style: AppTextStyles.caption),
          Text(agentName, style: AppTextStyles.titleLarge),
        ],
      ),
    ),
    // Icônes actions
    _HeaderIconButton(icon: Icons.chat_bubble_outline),
    const SizedBox(width: 8),
    _HeaderIconButton(icon: Icons.help_outline),
    const SizedBox(width: 8),
    _HeaderIconButton(icon: Icons.notifications_outlined, hasBadge: true),
  ],
)

// Widget icône header
class _HeaderIconButton extends StatelessWidget {
  // Carré arrondi 40x40, fond blanc, bordure légère
  // BoxDecoration: color white, borderRadius 12, border Border.all(color: AppColors.border)
  // BoxShadow: color primary 4%, blurRadius 8
}
```

---

### 4.2 Hero Card — Solde Total

**Fichier :** `widgets/balance_hero_card.dart`

| Élément | Spec |
|---|---|
| Fond | `LinearGradient(#1A3C6E → #2356A8 → #1B8C5E)` · angle 145° |
| Radius | `BorderRadius.circular(20)` |
| Padding | `EdgeInsets.all(20)` |
| Margin | `EdgeInsets.symmetric(horizontal: 20, vertical: 8)` |
| Hauteur | ~160px |

**Contenu :**

| Élément | Style |
|---|---|
| Label "Solde total · N SIM actives" | 12px, blanc 60%, regular |
| Montant "485 000" | 38px, blanc, bold 800, `Roboto Mono` |
| Suffix "FCFA" | 18px, blanc 60%, regular, baseline aligné |
| Icône œil (top-right) | Cercle 36px, fond blanc 15%, `Icons.visibility` blanc |
| Pill bénéfice | Fond vert 20%, bordure vert 35%, "↑ + 12 500 FCFA aujourd'hui" |
| Décoration cercles | 2× `Stack` `Positioned` — cercles semi-transparents blancs |

**Icône œil hero card :**
```dart
// Positionné en Positioned(top: 16, right: 16) dans un Stack
GestureDetector(
  onTap: () {
    ref.read(heroBalanceVisibleProvider.notifier).toggle();
    HapticFeedback.lightImpact();
  },
  child: Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(0.15),
    ),
    child: Icon(
      isVisible ? Icons.visibility : Icons.visibility_off,
      color: Colors.white,
      size: 18,
    ),
  ),
)
```

**Animation CountUp sur le montant :**
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: totalBalance),
  duration: const Duration(milliseconds: 700),
  curve: Curves.easeOutCubic,
  builder: (context, value, child) {
    return Text(
      FcfaFormatter.format(value),
      style: AppTextStyles.heroAmount,
    );
  },
)
```

---

### 4.3 Section "Mes SIM"

**Fichier :** `widgets/sim_cards_section.dart`

#### Header section
```dart
Row(
  children: [
    Text('Mes SIM', style: AppTextStyles.sectionTitle),
    const Spacer(),
    TextButton(
      onPressed: () => context.push('/dashboard/sims'),
      child: Row(children: [
        Text('Gérer', style: TextStyle(color: AppColors.primaryLight, fontSize: 13)),
        Icon(Icons.chevron_right, color: AppColors.primaryLight, size: 16),
      ]),
    ),
  ],
)
```

#### SIM Card individuelle (format LARGE — pas scroll horizontal)
**Fichier :** `widgets/sim_balance_card.dart`
**Layout :** `GridView` 2 colonnes ou `Row` avec 2 `Expanded`

| Élément | Spec |
|---|---|
| Fond normal | `Colors.white` |
| Fond faible | `Color(0xFFFFFDE7)` (jaune très clair) |
| Radius | `BorderRadius.circular(16)` |
| Bordure normale | `Border.all(color: AppColors.border, width: 1)` |
| Bordure faible | `Border.all(color: AppColors.warning.withOpacity(0.4), width: 1.5)` |
| Padding | `EdgeInsets.all(14)` |
| Ombre | `BoxShadow(color: primary.withOpacity(0.05), blurRadius: 10, offset: Offset(0,2))` |

**Header de la card (ligne 1) :**
```
[Logo OM]  Orange Money    [👁]  [⋮]
           07•••234
```
- Logo : carré 36px radius 10px, gradient par opérateur
- Nom : 13px bold `textPrimary`
- Numéro : 11px `textSecondary`
- Œil individuel : `Icons.visibility` / `Icons.visibility_off` — 20px `textSecondary`
- Menu ⋮ : `Icons.more_vert` — 20px `textSecondary` → ouvre `PopupMenuButton`

**PopupMenu options (⋮) :**
- ✏️ Modifier le numéro
- 🔔 Configurer l'alerte
- 🔄 Mettre à jour le solde
- ⛔ Désactiver la puce

**Corps de la card :**
```
250 000  FCFA         ← montant avec floutage possible
● Solde OK            ← statut coloré
──────────────────    ← Divider léger
[🕐 Historique]  [⊕ Recharger]   ← 2 boutons texte
```

**Logos opérateurs :**
```dart
// Gradients par opérateur
'OM'     : LinearGradient([Color(0xFFFF6200), Color(0xFFFF8C42)])
'MOOV'   : LinearGradient([Color(0xFF0057B8), Color(0xFF2E80D8)])
'TELECEL': LinearGradient([Color(0xFF1B8C5E), Color(0xFF22C97A)])
'MTN'    : LinearGradient([Color(0xFFFFCC00), Color(0xFFFFE566)]) // texte noir
'WAVE'   : LinearGradient([Color(0xFF1A73E8), Color(0xFF4BA3F5)])
'CORIS'  : LinearGradient([Color(0xFF8B1A1A), Color(0xFFBF4040)])
```

**Floutage solde individuel :**
```dart
// StateProvider par operatorCode
final simVisibilityProvider = StateProvider.family<bool, String>(
  (ref, operatorCode) => true, // true = visible par défaut
);

// Widget montant
Consumer(
  builder: (context, ref, _) {
    final isVisible = ref.watch(simVisibilityProvider(operatorCode));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isVisible
        ? Text(FcfaFormatter.format(balance), key: ValueKey('visible'))
        : ImageFiltered(
            key: ValueKey('blurred'),
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Text(FcfaFormatter.format(balance)),
          ),
    );
  },
)
```

**Boutons bas de card :**
```dart
// Divider puis Row avec 2 TextButton
Row(
  children: [
    Expanded(
      child: TextButton.icon(
        onPressed: () => context.push('/transactions?sim=$operatorCode'),
        icon: Icon(Icons.history, size: 14, color: AppColors.textSecondary),
        label: Text('Historique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    ),
    Container(width: 1, height: 16, color: AppColors.border),
    Expanded(
      child: TextButton.icon(
        onPressed: () => context.push('/operations/recharge?sim=$operatorCode'),
        icon: Icon(Icons.add_circle_outline, size: 14, color: AppColors.textSecondary),
        label: Text('Recharger', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    ),
  ],
)
```

**Statuts :**
| Condition | Dot | Texte | Couleur texte |
|---|---|---|---|
| `balance >= threshold` | `#22C97A` | "Solde OK" | `textSecondary` |
| `0 < balance < threshold` | `#F59E0B` | "Solde faible" | `#F59E0B` bold |
| `balance == 0` | `#EF4444` | "Solde vide" | `#EF4444` bold |

---

### 4.4 Actions Rapides

**Fichier :** `widgets/quick_actions_row.dart`
**Layout :** `Row` avec 4 `Expanded` — pas de Grid

| Action | Icône | Icône bg | Label | Sous-label | Route |
|---|---|---|---|---|---|
| Dépôt | `arrow_downward` | `#1B8C5E` | "Dépôt" | "Encaisser" | `/operations/depot` |
| Retrait | `arrow_upward` | `#2356A8` | "Retrait" | "Décaisser" | `/operations/retrait` |
| Transfert | `swap_horiz` | `#534AB7` | "Transfert" | "Inter-réseau" | `/operations/transfert` |
| Recharge | `phone_android` | `#1B8C5E` | "Recharge" | "Crédit téléphone" | `/operations/recharge` |

```dart
// Structure d'un item action
Column(
  children: [
    // Cercle icône 56px
    Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor,
        boxShadow: [BoxShadow(color: iconColor.withOpacity(0.3), blurRadius: 12, offset: Offset(0,4))],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
    const SizedBox(height: 8),
    Text(label, style: AppTextStyles.actionLabel),   // 13px bold
    Text(subLabel, style: AppTextStyles.caption),    // 11px textSecondary
  ],
)
```

**Container global actions :**
```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
  ),
  child: Row(children: [...4 actions...]),
)
```

---

### 4.5 Bannière Promotionnelle (Carousel)

**Fichier :** `widgets/promo_banner_carousel.dart`

- `PageView` avec `PageController`
- Dots indicateurs en bas (actif : `primary` 10px, inactif : `border` 8px)
- Auto-scroll toutes les 5 secondes (`Timer.periodic`)
- Contenu configurable depuis l'API backend (`/dashboard/banners/`)
- En Phase 2 : contenu hardcodé (1 seule bannière mock)

**Structure d'une bannière :**
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
  ),
  child: Row(
    children: [
      // Texte gauche
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: Text('En savoir plus'),
              // Bordure primary, texte primaryLight, radius 20
            ),
          ],
        ),
      ),
      // Illustration droite (Image.asset ou Lottie)
      Expanded(flex: 2, child: Image.asset('assets/images/banner_finance.png')),
    ],
  ),
)
```

---

### 4.6 Bottom Navigation Bar

**Fichier :** `core/widgets/sic_bottom_nav.dart`
**Géré par :** `go_router` `ShellRoute`

| Tab | Icône off | Icône on | Label | Route |
|---|---|---|---|---|
| Accueil | `home_outlined` | `home` | "Accueil" | `/dashboard` |
| Transactions | `description_outlined` | `description` | "Transactions" | `/transactions` |
| Profil | `person_outline` | `person` | "Profil" | `/profil` |

```dart
BottomNavigationBar(
  backgroundColor: AppColors.surface,
  selectedItemColor: AppColors.primary,
  unselectedItemColor: AppColors.textTertiary,
  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
  elevation: 0,
  // Pip vert sous l'onglet actif via Stack + Positioned
)
```

---

## 5. PROVIDERS RIVERPOD

```dart
// Tous les providers nécessaires pour cet écran

// 1. Données principales
dashboardNotifierProvider       // AsyncNotifier<AgentSummary>

// 2. Visibilité solde hero card
heroBalanceVisibleProvider      // StateProvider<bool> — défaut: true

// 3. Visibilité solde par SIM (individuel)
simVisibilityProvider           // StateProvider.family<bool, String>(operatorCode)
// Usage: ref.watch(simVisibilityProvider('OM'))

// 4. Page active bannière
bannerPageProvider              // StateProvider<int> — défaut: 0

// 5. Injection de dépendances
dashboardLocalDatasourceProvider
dashboardRepositoryProvider
getDashboardSummaryProvider
```

---

## 6. DONNÉES MOCKÉES

```dart
AgentSummary(
  agentCode            : 'AGT-0042',
  agentName            : 'Koné Moussa',
  agentInitials        : 'KM',
  totalBalance         : 485000.0,
  benefits             : BenefitPeriod(
    today  : 12500.0,
    week   : 87300.0,
    month  : 312000.0,
    total  : 1250000.0,
  ),
  balances             : [
    BalanceSummary(
      operatorCode   : 'OM',
      operatorName   : 'Orange Money',
      phoneNumber    : '0701234234',  // affiché masqué : 07•••234
      balance        : 250000.0,
      isLow          : false,
      alertThreshold : 50000.0,
      lastUpdated    : DateTime.now(),
    ),
    BalanceSummary(
      operatorCode   : 'MOOV',
      operatorName   : 'Moov Money',
      phoneNumber    : '0601238891',  // 06•••891
      balance        : 35000.0,
      isLow          : true,
      alertThreshold : 50000.0,
      lastUpdated    : DateTime.now(),
    ),
  ],
  transactionCountToday : 8,
  hasUnreadNotifications: true,
)

// Bannière mock
PromoBanner(
  title    : 'Gérez votre argent\nen toute simplicité',
  subtitle : 'Sécurisé, rapide et toujours\nà portée de main.',
  ctaLabel : 'En savoir plus',
  imageAsset: 'assets/images/banner_finance.png',
)
```

---

## 7. ANIMATIONS

| Élément | Type | Durée | Courbe |
|---|---|---|---|
| Solde hero | CountUp `TweenAnimationBuilder` | 700ms | `easeOutCubic` |
| Hero card | FadeIn + SlideY(0.2→0) | 400ms | `easeOut` |
| SIM cards | Stagger FadeIn (80ms entre chaque) | 300ms | `easeOut` |
| Floutage solde | `AnimatedSwitcher` blur | 300ms | `easeInOut` |
| Œil hero | Scale 0.9 + opacity on tap | 150ms | `easeIn` |
| Actions icônes | Scale 0.92 on tap | 100ms | `easeIn` |
| Bannière | Auto-scroll `PageView` | 400ms | `easeInOut` |

---

## 8. INTERACTIONS & NAVIGATION

| Interaction | Action |
|---|---|
| Tap œil hero | Toggle `heroBalanceVisibleProvider` + haptic light |
| Tap œil SIM | Toggle `simVisibilityProvider(code)` + haptic light |
| Tap ⋮ SIM | Ouvre `PopupMenuButton` (modifier / alerte / solde / désactiver) |
| Tap "Historique" dans card | `context.push('/transactions?sim=OM')` |
| Tap "Recharger" dans card | `context.push('/operations/recharge?sim=OM')` |
| Tap "Gérer" header SIM | `context.push('/dashboard/sims')` |
| Tap Dépôt | `context.push('/operations/depot')` + haptic medium |
| Tap Retrait | `context.push('/operations/retrait')` + haptic medium |
| Tap Transfert | `context.push('/operations/transfert')` + haptic medium |
| Tap Recharge | `context.push('/operations/recharge')` + haptic medium |
| Pull-to-refresh | `ref.invalidate(dashboardNotifierProvider)` |
| Tap "En savoir plus" bannière | `context.push('/info/banniere/${banner.id}')` |

---

## 9. ACCESSIBILITÉ

```dart
// Chaque SIM card
Semantics(
  label: 'Orange Money, numéro 07 234, solde 250 000 FCFA, Solde OK',
  child: SimBalanceCard(...),
)

// Montant flou : ne pas lire à voix haute
Semantics(
  excludeSemantics: isBlurred,
  label: isBlurred ? 'Solde masqué. Appuyez pour révéler.' : null,
  child: balanceWidget,
)

// Zones tactiles minimum 48×48px sur tous les boutons
```

---

## 10. CHECKLIST DE VALIDATION

**Données et état :**
- [ ] Données mock s'affichent correctement
- [ ] Pull-to-refresh recharge les données
- [ ] Indicateur de chargement (SicLoading) pendant le fetch
- [ ] État d'erreur avec bouton "Réessayer"

**Hero Card :**
- [ ] Gradient bleu → vert visible
- [ ] Animation CountUp solde total au premier chargement
- [ ] Œil hero masque/révèle le solde total
- [ ] Pill bénéfice s'affiche en vert

**SIM Cards :**
- [ ] 2 cards en grille côte à côte
- [ ] Card Moov fond jaune clair (solde faible)
- [ ] Œil individuel fonctionne par card
- [ ] Menu ⋮ ouvre les options
- [ ] Bouton "Historique" navigue correctement
- [ ] Bouton "Recharger" navigue correctement
- [ ] Numéro masqué (07•••234)

**Actions rapides :**
- [ ] 4 boutons en ligne horizontale
- [ ] Couleurs correctes par action
- [ ] HapticFeedback au tap
- [ ] Navigation vers les bons écrans (Phase 3)

**Bannière :**
- [ ] S'affiche avec texte et illustration
- [ ] Dots carousel visibles

**Général :**
- [ ] `flutter analyze` : 0 erreur
- [ ] Test unitaire `GetDashboardSummary` passe
- [ ] Testé sur Pixel 6 émulateur (360px)
- [ ] Testé sur petit écran 320px (pas de débordement)
- [ ] SafeArea respecté (encoche + barre navigation)

---

## 11. FICHIERS À CRÉER

```
lib/features/dashboard/
├── domain/
│   ├── entities/
│   │   ├── agent_summary.dart
│   │   ├── balance_summary.dart
│   │   ├── benefit_period.dart
│   │   └── promo_banner.dart
│   ├── repositories/
│   │   └── dashboard_repository.dart
│   └── usecases/
│       └── get_dashboard_summary.dart
├── data/
│   ├── models/
│   │   ├── agent_summary_model.dart
│   │   ├── balance_summary_model.dart
│   │   └── promo_banner_model.dart
│   ├── datasources/
│   │   ├── dashboard_local_datasource.dart
│   │   └── dashboard_remote_datasource.dart  ← commenté
│   └── repositories/
│       └── dashboard_repository_impl.dart
└── presentation/
    ├── providers/
    │   └── dashboard_provider.dart
    ├── screens/
    │   └── dashboard_screen.dart
    └── widgets/
        ├── balance_hero_card.dart
        ├── sim_cards_section.dart
        ├── sim_balance_card.dart
        ├── quick_actions_row.dart
        └── promo_banner_carousel.dart
```
