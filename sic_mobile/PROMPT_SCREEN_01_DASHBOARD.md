# PROMPT — Coder le Dashboard Principal SIC
## Flutter · Clean Architecture · Riverpod · Phase 2

> Copie ce prompt dans Cursor (@codebase) ou Claude.
> Lis SCREEN_01_DASHBOARD.md avant de lancer ce prompt.
> Exécute les étapes dans l'ordre — commit entre chaque étape.

---

## CONTEXTE À FOURNIR AVANT LE PROMPT

Assure-toi que ces fichiers sont déjà créés avant de lancer :
- `lib/core/constants/app_colors.dart`
- `lib/core/constants/app_text_styles.dart`
- `lib/core/constants/app_spacing.dart`
- `lib/core/errors/failures.dart`
- `lib/core/usecases/usecase.dart`
- `lib/core/utils/fcfa_formatter.dart`
- `lib/core/widgets/sic_loading.dart`
- `lib/core/widgets/sic_error_widget.dart`

Si ces fichiers n'existent pas, lance d'abord les prompts de l'ÉTAPE 0
dans `PROMPTS_PHASE2.md`.

---

## ÉTAPE 1 — Domain Layer

```
Tu es un développeur Flutter senior qui construit l'app SIC Mobile,
une application fintech pour agents Mobile Money en Afrique de l'Ouest.
Tu suis strictement la Clean Architecture et les principes SOLID.

Crée la couche Domain de la feature Dashboard.
Le Domain est du Dart pur — aucun import Flutter, aucun import de packages
externes sauf dartz et equatable.

━━━ FICHIER 1 : lib/features/dashboard/domain/entities/benefit_period.dart

class BenefitPeriod extends Equatable :
- today: double
- week: double
- month: double
- total: double
- constructeur const
- props: toutes les propriétés

━━━ FICHIER 2 : lib/features/dashboard/domain/entities/balance_summary.dart

class BalanceSummary extends Equatable :
- operatorCode: String       ('OM', 'MOOV', 'TELECEL', 'MTN', 'WAVE', 'CORIS')
- operatorName: String
- phoneNumber: String        (ex: '0701234234')
- balance: double
- isLow: bool                (calculé : balance < alertThreshold)
- alertThreshold: double
- lastUpdated: DateTime
- constructeur const
- getter maskedPhone → '07•••234' (affiche 2 premiers + 3 derniers chiffres)
- props: toutes les propriétés

━━━ FICHIER 3 : lib/features/dashboard/domain/entities/promo_banner.dart

class PromoBanner extends Equatable :
- id: String
- title: String
- subtitle: String
- ctaLabel: String
- ctaRoute: String
- imageAsset: String
- constructeur const
- props: toutes les propriétés

━━━ FICHIER 4 : lib/features/dashboard/domain/entities/agent_summary.dart

class AgentSummary extends Equatable :
- agentCode: String
- agentName: String
- totalBalance: double
- benefits: BenefitPeriod
- balances: List<BalanceSummary>
- transactionCountToday: int
- hasUnreadNotifications: bool
- banners: List<PromoBanner>
- getter agentInitials → 2 premières lettres du prénom et nom
- getter activeSimCount → balances.length
- constructeur const
- props: toutes les propriétés

━━━ FICHIER 5 : lib/features/dashboard/domain/repositories/dashboard_repository.dart

abstract class DashboardRepository :
- Future<Either<Failure, AgentSummary>> getDashboardSummary()

━━━ FICHIER 6 : lib/features/dashboard/domain/usecases/get_dashboard_summary.dart

class GetDashboardSummary implements UseCase<AgentSummary, NoParams> :
- injecte DashboardRepository via constructeur
- call(NoParams) délègue au repository

Contraintes strictes :
- Aucun import Flutter dans aucun de ces fichiers
- Constructeurs const partout
- Props Equatable complètes sur chaque entity
- Pas de logique métier dans les entities sauf les getters simples définis
```

**Commit :**
```
git add . && git commit -m "feat(dashboard): add domain entities and usecase"
```

---

## ÉTAPE 2 — Data Layer (Mock)

```
Crée la couche Data de la feature Dashboard pour SIC Mobile.
Le backend Django n'est pas encore disponible.
Utilise des données mockées réalistes.

━━━ FICHIER 1 : lib/features/dashboard/data/models/balance_summary_model.dart

class BalanceSummaryModel extends BalanceSummary :
- factory fromJson(Map<String, dynamic> json)
  - 'operator_code', 'operator_name', 'phone_number', 'balance' (double)
  - 'alert_threshold' (double), 'last_updated' (ISO 8601 string → DateTime)
  - isLow calculé : balance < alertThreshold
- Map<String, dynamic> toJson()
- factory mock(String operatorCode) avec données réalistes par opérateur :
  - 'OM'     → Orange Money, 07012340234, balance 250000, threshold 50000
  - 'MOOV'   → Moov Money,   06012348891, balance 35000,  threshold 50000 (isLow!)
  - 'TELECEL'→ Telecel,      07012345567, balance 200000, threshold 50000

━━━ FICHIER 2 : lib/features/dashboard/data/models/agent_summary_model.dart

class AgentSummaryModel extends AgentSummary :
- factory fromJson(Map<String, dynamic> json)
- Map<String, dynamic> toJson()
- factory mock() → données réalistes :
  agentCode: 'AGT-0042'
  agentName: 'Koné Moussa'
  totalBalance: 485000.0  (somme des balances)
  benefits: BenefitPeriod(today:12500, week:87300, month:312000, total:1250000)
  balances: [BalanceSummaryModel.mock('OM'), mock('MOOV')]
  transactionCountToday: 8
  hasUnreadNotifications: true
  banners: [PromoBannerModel.mock()]

━━━ FICHIER 3 : lib/features/dashboard/data/models/promo_banner_model.dart

class PromoBannerModel extends PromoBanner :
- factory fromJson / toJson
- factory mock() :
  id: 'banner_001'
  title: 'Gérez votre argent\nen toute simplicité'
  subtitle: 'Sécurisé, rapide et toujours\nà portée de main.'
  ctaLabel: 'En savoir plus'
  ctaRoute: '/info/sic'
  imageAsset: 'assets/images/banner_finance.png'

━━━ FICHIER 4 : lib/features/dashboard/data/datasources/dashboard_local_datasource.dart

class DashboardLocalDatasource :
- Future<AgentSummaryModel> getDashboardSummary() :
  await Future.delayed(const Duration(milliseconds: 700))
  retourne AgentSummaryModel.mock()
  (le délai simule la latence réseau)

━━━ FICHIER 5 : lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart

class DashboardRemoteDatasource :
TOUT LE CONTENU EST COMMENTÉ avec // TODO: uncomment when backend ready
Inclure le code Dio complet mais commenté :
- GET /dashboard/summary/ avec auth JWT
- Parsing du JSON en AgentSummaryModel
- Throw ServerException si erreur HTTP
Ajouter un commentaire en tête de fichier :
// REMOTE DATASOURCE — Backend Django non disponible en Phase 2
// Décommenter et configurer quand le backend est prêt
// Endpoint : GET /api/v1/dashboard/summary/

━━━ FICHIER 6 : lib/features/dashboard/data/repositories/dashboard_repository_impl.dart

class DashboardRepositoryImpl implements DashboardRepository :
- injecte DashboardLocalDatasource via constructeur
- getDashboardSummary() :
  try → Right(await datasource.getDashboardSummary())
  catch ServerException → Left(ServerFailure(e.message))
  catch Exception → Left(ServerFailure('Erreur inattendue'))
```

**Commit :**
```
git add . && git commit -m "feat(dashboard): add data layer with mock datasource"
```

---

## ÉTAPE 3 — Providers Riverpod

```
Crée les providers Riverpod pour la feature Dashboard de SIC Mobile.
Utilise riverpod_annotation (@riverpod) pour la génération de code.

━━━ FICHIER : lib/features/dashboard/presentation/providers/dashboard_provider.dart

Crée ces providers dans l'ordre :

1. dashboardLocalDatasourceProvider
   Provider<DashboardLocalDatasource> → retourne DashboardLocalDatasource()

2. dashboardRepositoryProvider
   Provider<DashboardRepository> →
   retourne DashboardRepositoryImpl(ref.read(dashboardLocalDatasourceProvider))

3. getDashboardSummaryProvider
   Provider<GetDashboardSummary> →
   retourne GetDashboardSummary(ref.read(dashboardRepositoryProvider))

4. @riverpod DashboardNotifier extends _$DashboardNotifier
   AsyncNotifier<AgentSummary>
   - build() : appelle GetDashboardSummary, gère Either → throw Failure si Left
   - refresh() async : ref.invalidateSelf() + await future
   
5. heroBalanceVisibleProvider
   StateProvider<bool> → défaut true (solde visible)

6. simVisibilityProvider
   StateProvider.family<bool, String> → défaut true
   (paramètre = operatorCode)
   Usage: ref.watch(simVisibilityProvider('OM'))

7. bannerPageProvider
   StateProvider<int> → défaut 0

Après création, lance :
dart run build_runner build --delete-conflicting-outputs

Contraintes :
- Pas de logique métier dans les providers
- Les erreurs Failure doivent être throwées pour que .when(error:) les attrape
- Nommage strict : suffixe Provider ou Notifier
```

**Commit :**
```
dart run build_runner build --delete-conflicting-outputs
git add . && git commit -m "feat(dashboard): add Riverpod providers"
```

---

## ÉTAPE 4 — Widgets (dans l'ordre)

### SOUS-ÉTAPE 4.1 — Hero Card

```
Crée lib/features/dashboard/presentation/widgets/balance_hero_card.dart
pour SIC Mobile. C'est la carte principale du dashboard.

DESIGN EXACT (basé sur le mockup validé) :
- Gradient: LinearGradient(colors:[#1A3C6E, #2356A8, #1B8C5E], angle 145°)
- BorderRadius: 20px
- Padding: EdgeInsets.all(20)
- Margin: EdgeInsets.symmetric(horizontal: 20)
- Hauteur: environ 160px

CONTENU (Stack avec Positioned pour l'œil et les cercles décoratifs) :

FOND DÉCORATIF (Positioned, non interactif) :
- Cercle 1 : Positioned(top:-50, right:-40), 160px, blanc 5% opacité
- Cercle 2 : Positioned(bottom:-40, left:60), 120px, vert 8% opacité

CONTENU PRINCIPAL (Column) :
1. Label : "Solde total · {activeSimCount} SIM actives"
   Style: 12px, blanc 60%, regular

2. Row [Montant + Œil] :
   - Montant avec CountUp TweenAnimationBuilder (0 → totalBalance, 700ms, easeOutCubic)
     Style: 38px, blanc, bold, Roboto Mono (ou monospace)
     Suffix " FCFA" 18px blanc 60%
   - Spacer()
   - Bouton œil : GestureDetector → cercle 36px blanc 15%
     Icons.visibility si visible, Icons.visibility_off si masqué
     HapticFeedback.lightImpact() au tap

3. SizedBox height 12

4. Pill bénéfice :
   Container: padding H12/V6, radius 20, fond vert 20%, bordure vert 35%
   Contenu: "↑ + {FcfaFormatter.format(todayBenefits)} aujourd'hui"
   Style: 12px, #22C97A, bold

PARAMÈTRES du widget :
- totalBalance: double
- todayBenefits: double  
- activeSimCount: int
- isVisible: bool
- onToggleVisibility: VoidCallback

ANIMATION montant flou quand isVisible = false :
Si !isVisible → AnimatedOpacity(opacity: 0.3) + filtre blur léger sur le montant
Si isVisible → montant normal

Contraintes :
- const constructor
- Pas de ref Riverpod dans ce widget — état géré par le parent
- Toutes les couleurs depuis AppColors
```

### SOUS-ÉTAPE 4.2 — SIM Balance Card

```
Crée lib/features/dashboard/presentation/widgets/sim_balance_card.dart
pour SIC Mobile.

C'est la card d'une SIM individuelle. DESIGN EXACT du mockup validé :

FOND :
- Normal : Colors.white
- Faible (isLow) : Color(0xFFFFFDE7) fond jaune très clair
- BorderRadius: 16px
- Bordure normale : Border.all(color: Color(0xFFDCE6F0))
- Bordure faible  : Border.all(color: Color(0xFFF59E0B).withOpacity(0.4), width: 1.5)
- BoxShadow : blurRadius 10, offset (0,2), color primary 5%
- Padding: EdgeInsets.all(14)

STRUCTURE INTERNE (Column) :

──── ROW 1 : Header ────
Row :
[Logo opérateur 36px] [Expanded: Nom + numéro masqué] [Icône œil 20px] [Icône ⋮ 20px]

Logo opérateur (Container 36px, radius 10, gradient) :
- 'OM'     → gradient [#FF6200, #FF8C42], texte "OM"
- 'MOOV'   → gradient [#0057B8, #2E80D8], texte "MV"
- 'TELECEL'→ gradient [#1B8C5E, #22C97A], texte "TC"
- 'MTN'    → gradient [#FFCC00, #FFE566], texte noir "MTN"
- 'WAVE'   → gradient [#1A73E8, #4BA3F5], texte "WV"
- fallback → gradient [#64748B, #94A3B8], 2 premières lettres

Nom : 13px, bold, textPrimary
Numéro masqué : depuis entity.maskedPhone — 11px, textSecondary

Icône œil : Icons.visibility / Icons.visibility_off — 20px textSecondary
Icône ⋮ : Icons.more_vert — 20px textSecondary
PopupMenuButton options :
  - "Modifier le numéro" (icon: edit)
  - "Configurer l'alerte" (icon: notifications)
  - "Mettre à jour le solde" (icon: refresh)
  - "Désactiver la puce" (icon: block, couleur danger)

──── CORPS ────
SizedBox(height: 12)

Montant + floutage :
Consumer pour lire simVisibilityProvider(operatorCode)
Si visible : Text(FcfaFormatter.format(balance)) 20px bold textPrimary Roboto Mono
             + suffix Text(' FCFA') 12px textSecondary
Si masqué  : ImageFiltered(blur sigmaX:8, sigmaY:8) sur le montant
AnimatedSwitcher duration 300ms entre les deux états

SizedBox(height: 6)

Statut Row [dot 7px + texte 12px] :
- isLow=false ET balance>0 → dot #22C97A, "Solde OK", textSecondary
- isLow=true              → dot #F59E0B, "Solde faible", #F59E0B bold
- balance==0              → dot #EF4444, "Solde vide", #EF4444 bold

──── FOOTER ────
Divider(height: 20, color: AppColors.border)

Row 2 boutons texte :
[🕐 Historique]  |  [⊕ Recharger]

Chaque bouton : TextButton.icon, icône 14px + label 12px textSecondary
Séparateur vertical : Container(width:1, height:16, color:border)

PARAMÈTRES :
- balance: BalanceSummary
- onHistoryTap: VoidCallback
- onRechargeTap: VoidCallback
- onMenuSelect: Function(String action) — 'edit'|'alert'|'update'|'disable'

INTERACTION :
- GestureDetector sur toute la card (hors boutons) → HapticFeedback.lightImpact()
- Tap card → callback onTap (ouvre BalanceUpdateBottomSheet)

Contraintes identiques aux autres widgets.
```

### SOUS-ÉTAPE 4.3 — Quick Actions Row

```
Crée lib/features/dashboard/presentation/widgets/quick_actions_row.dart
pour SIC Mobile.

CONTAINER :
- fond blanc, radius 16, bordure AppColors.border
- padding EdgeInsets.symmetric(vertical: 16, horizontal: 8)
- BoxShadow léger primary 4%

CONTENU : Row de 4 Expanded

Chaque item (Column) :
1. Container cercle 56px :
   - fond : couleur définie par action
   - BoxShadow : couleur.withOpacity(0.3), blurRadius 12, offset (0,4)
   - Icon 24px blanc

2. SizedBox height 8

3. Text label : 13px, bold, textPrimary

4. Text sous-label : 11px, textSecondary

DÉFINITION DES 4 ACTIONS :
action 1 — Dépôt :
  icône: Icons.arrow_downward_rounded
  couleur cercle: Color(0xFF1B8C5E)
  label: 'Dépôt'
  sous-label: 'Encaisser'
  route: '/operations/depot'

action 2 — Retrait :
  icône: Icons.arrow_upward_rounded
  couleur cercle: Color(0xFF2356A8)
  label: 'Retrait'
  sous-label: 'Décaisser'
  route: '/operations/retrait'

action 3 — Transfert :
  icône: Icons.swap_horiz_rounded
  couleur cercle: Color(0xFF534AB7)
  label: 'Transfert'
  sous-label: 'Inter-réseau'
  route: '/operations/transfert'

action 4 — Recharge :
  icône: Icons.phone_android_rounded
  couleur cercle: Color(0xFF1B8C5E)
  label: 'Recharge'
  sous-label: 'Crédit téléphone'
  route: '/operations/recharge'

INTERACTION :
- GestureDetector avec onTapDown → scale 0.92 (AnimatedScale)
- onTapUp → scale 1.0
- onTap → HapticFeedback.mediumImpact() + context.push(route)

PARAMÈTRE : onActionTap: Function(String route)
```

### SOUS-ÉTAPE 4.4 — Bannière Promo Carousel

```
Crée lib/features/dashboard/presentation/widgets/promo_banner_carousel.dart
pour SIC Mobile.

FONCTIONNEMENT :
- PageView.builder avec PageController
- Auto-scroll : Timer.periodic(5 secondes) → nextPage
- Annuler le Timer dans dispose() si StatefulWidget
- Dots indicateurs : actif primary 10px, inactif border 8px arrondi

UNE BANNIÈRE (Container) :
- fond blanc, radius 16, bordure border
- padding EdgeInsets.all(20)
- BoxShadow primary 4%
Row :
  Expanded(flex:3) → Column :
    Text(title) : 16px, bold, textPrimary, maxLines 2
    SizedBox 6
    Text(subtitle) : 12px, textSecondary, maxLines 2
    SizedBox 12
    OutlinedButton :
      label "${ctaLabel} ›"
      bordure: primaryLight, radius 20
      texte: 12px primaryLight bold
      padding: H16/V8
  Expanded(flex:2) →
    Image.asset(imageAsset, fit: BoxFit.contain, height: 100)
    (si asset absent : placeholder Container bleu clair avec icône)

DOTS :
Row centré, gap 6px entre chaque dot
AnimatedContainer : actif → width 10, inactif → width 8

PARAMÈTRES :
- banners: List<PromoBanner>
- initialPage: int (depuis bannerPageProvider)
- onPageChanged: Function(int page)

Note Phase 2 : si banners.isEmpty → ne rien afficher (SizedBox.shrink())
```

**Commit étape 4 :**
```
git add . && git commit -m "feat(dashboard): add all dashboard widgets"
```

---

## ÉTAPE 5 — Écran Principal

```
Crée lib/features/dashboard/presentation/screens/dashboard_screen.dart
pour SIC Mobile. C'est l'écran complet assemblant tous les widgets.

TYPE : ConsumerWidget

STRUCTURE GLOBALE :
Scaffold(
  backgroundColor: AppColors.background,
  body: SafeArea(
    child: state.when(
      loading: SicLoading(),
      error: SicErrorWidget(onRetry),
      data: _DashboardContent(summary),
    )
  ),
  bottomNavigationBar: SicBottomNav(currentIndex: 0),
)

_DashboardContent est un widget privé StatelessWidget :
RefreshIndicator(
  onRefresh: () async => ref.read(dashboardNotifierProvider.notifier).refresh(),
  color: AppColors.primary,
  child: SingleChildScrollView(
    physics: AlwaysScrollableScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        ── 1. HEADER ──────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: _DashboardHeader(summary: summary),
        )

        ── 2. HERO CARD ───────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: BalanceHeroCard(
            totalBalance: summary.totalBalance,
            todayBenefits: summary.benefits.today,
            activeSimCount: summary.activeSimCount,
            isVisible: ref.watch(heroBalanceVisibleProvider),
            onToggleVisibility: () {
              ref.read(heroBalanceVisibleProvider.notifier).update((s) => !s);
              HapticFeedback.lightImpact();
            },
          ),
        )

        ── 3. SECTION MES SIM ─────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: _SimSectionHeader(onGererTap: () => context.push('/dashboard/sims')),
        )
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: summary.balances.map((sim) =>
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: sim != summary.balances.last ? 10 : 0),
                  child: SimBalanceCard(
                    balance: sim,
                    onHistoryTap: () => context.push('/transactions?sim=${sim.operatorCode}'),
                    onRechargeTap: () => context.push('/operations/recharge?sim=${sim.operatorCode}'),
                    onMenuSelect: (action) => _handleSimAction(context, ref, sim, action),
                  ),
                ),
              )
            ).toList(),
          ),
        )

        ── 4. ACTIONS RAPIDES ─────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Actions rapides', style: AppTextStyles.sectionTitle),
        )
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: QuickActionsRow(
            onActionTap: (route) => context.push(route),
          ),
        )

        ── 5. BANNIÈRE PROMO ──────────────────────
        if (summary.banners.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: PromoBannerCarousel(
              banners: summary.banners,
              initialPage: ref.watch(bannerPageProvider),
              onPageChanged: (page) => ref.read(bannerPageProvider.notifier).state = page,
            ),
          )

        SizedBox(height: 16),
      ],
    ),
  ),
)

_DashboardHeader widget privé :
Row :
  CircleAvatar(radius:26, bg:#22C97A, child: Text(initiales, 14px bold dark))
  SizedBox(12)
  Expanded → Column :
    Text('Bonjour 👋', style: caption textSecondary)
    Text(agentName, style: titleLarge bold)
  Row icônes :
    _HeaderIconBtn(Icons.chat_bubble_outline)
    SizedBox(8)
    _HeaderIconBtn(Icons.help_outline)
    SizedBox(8)
    _HeaderIconBtn(Icons.notifications_outlined, badge: hasUnread)

_HeaderIconBtn widget privé :
  Container 40x40, radius 12
  fond blanc, bordure AppColors.border, shadow primary 4%
  IconButton icon 20px textPrimary
  si badge: Stack avec Positioned top-right dot rouge 8px

_handleSimAction méthode privée :
  'edit'    → showModalBottomSheet EditSimSheet
  'alert'   → context.push('/dashboard/alerts?sim=code')
  'update'  → showModalBottomSheet BalanceUpdateBottomSheet
  'disable' → showDialog confirmation → ref.read(...).toggleSim(id)

ANIMATIONS sur le build initial (flutter_animate) :
- Header : .fadeIn(duration:300ms).slideY(begin:-0.1)
- Hero card : .fadeIn(delay:100ms, duration:400ms).slideY(begin:0.1)
- SIM cards : .fadeIn(delay:200ms).slideY(begin:0.1)
- Actions : .fadeIn(delay:300ms)
- Bannière : .fadeIn(delay:400ms)

Contraintes :
- Aucune logique dans le build() — tout délégué aux sous-widgets
- Pas de Navigator.push() — toujours context.push() de go_router
- SafeArea wrapping le Scaffold body
- Tester avec summary.balances de 1 à 5 SIM (pas seulement 2)
```

**Commit étape 5 :**
```
git add . && git commit -m "feat(dashboard): assemble dashboard screen"
```

---

## ÉTAPE 6 — Tests Unitaires

```
Crée les tests pour la feature Dashboard de SIC Mobile.

━━━ test/features/dashboard/usecases/get_dashboard_summary_test.dart

Importe mockito, crée un mock de DashboardRepository.
Écris ces 3 tests :

test 1 : 'should return AgentSummary when repository call succeeds'
  - mock retourne Right(AgentSummaryModel.mock())
  - appelle GetDashboardSummary(mockRepo)(NoParams())
  - vérifie que result == Right(summary)

test 2 : 'should return ServerFailure when repository throws ServerException'
  - mock retourne Left(ServerFailure('Erreur serveur'))
  - vérifie que result == Left(ServerFailure)

test 3 : 'should compute correct totalBalance from balances list'
  - créer un AgentSummary avec 2 balances (250000 + 35000)
  - vérifier que totalBalance == 485000

━━━ test/features/dashboard/entities/balance_summary_test.dart

test 1 : 'maskedPhone should mask middle digits correctly'
  phoneNumber '0701234234' → maskedPhone '07•••234'
  phoneNumber '0601238891' → maskedPhone '06•••891'

test 2 : 'isLow should be true when balance < alertThreshold'
  balance: 35000, threshold: 50000 → isLow true
  balance: 250000, threshold: 50000 → isLow false

Utilise le style AAA (Arrange, Act, Assert) avec commentaires.
Nommage : 'should [résultat] when [condition]'
```

**Commit :**
```
git add . && git commit -m "test(dashboard): add unit tests for dashboard feature"
```

---

## ÉTAPE 7 — Vérification finale

```
Lance ces commandes dans l'ordre et corrige tout ce qui échoue :

1. dart run build_runner build --delete-conflicting-outputs
   → Doit terminer sans erreur

2. flutter analyze
   → Doit afficher "No issues found!"

3. flutter test
   → Doit afficher tous les tests en vert

4. flutter run
   → Lance l'app sur l'émulateur, vérifie visuellement :
     ✓ Header avec avatar vert KM
     ✓ Hero card gradient bleu → vert
     ✓ Animation CountUp du solde au chargement
     ✓ 2 SIM cards côte à côte (OM normal, Moov fond jaune)
     ✓ Œil hero masque le solde
     ✓ Œil individuel fonctionne par card
     ✓ Menu ⋮ ouvre les options
     ✓ 4 actions rapides avec couleurs
     ✓ Bannière promo en bas
     ✓ Pull-to-refresh fonctionne
     ✓ Bottom nav Accueil actif (bleu + pip vert)

Si tout est vert :
git add . && git commit -m "chore: dashboard screen Phase 2 complete and validated"
git push origin feature/phase2-dashboard
→ Ouvrir Pull Request vers develop sur GitHub
```

---

## PROMPT DE CORRECTION (si bugs visuels)

```
L'écran Dashboard de SIC Mobile présente ce problème visuel : [DÉCRIS LE PROBLÈME]

Voici le fichier concerné : [COLLE LE CODE]

Contexte :
- Palette : primary #1A3C6E, secondary #1B8C5E, success #22C97A
- Style fintech africain, soft UI, propre et lisible
- Testé sur Pixel 6 émulateur Android 13

Corrige uniquement ce problème sans modifier le reste.
Explique ce qui causait le bug avant de donner la correction.
```

---

## PROMPT D'OPTIMISATION PERFORMANCE (après validation)

```
L'écran Dashboard de SIC Mobile est fonctionnel.
Optimise-le pour les performances sur Android entrée de gamme (2Go RAM).

Vérifie et corrige :
1. Les widgets inutilement reconstruits — utiliser const partout possible
2. Les ListView sans builder (risque si liste longue)
3. Les images non mises en cache
4. Les animations qui bloquent le thread UI
5. Les providers trop larges (provoquent des rebuilds en cascade)

Pour chaque optimisation, indique :
- Le fichier et la ligne concernés
- Le problème de performance
- La correction appliquée
- L'impact estimé sur les performances
```
