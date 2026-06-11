# Prompts IA — Phase 2 étape par étape

> Utilise ces prompts dans Cursor, Claude ou GitHub Copilot Chat.
> Chaque étape a un objectif clair, des contraintes et un résultat attendu.
> Procède dans l'ordre — chaque étape construit sur la précédente.

---

## Comment utiliser ces prompts

1. Lis l'étape entière avant de lancer le prompt
2. Lance le prompt dans ton IA (Cursor recommandé pour Flutter)
3. Vérifie le résultat avec la checklist en bas de chaque étape
4. Commit avant de passer à l'étape suivante
5. Si le résultat est incorrect, utilise le "prompt de correction" indiqué

---

## ÉTAPE 0 — Fondations Core

**Objectif :** Créer toute la couche `core/` avant de toucher aux features.
**Durée estimée :** 2-3 heures
**Branche :** `feature/phase2-core`

---

### Prompt 0.1 — Thème et constantes visuelles

```
Tu es un développeur Flutter senior qui construit une app fintech mobile
pour agents Mobile Money en Afrique de l'Ouest.

Crée les fichiers suivants dans lib/core/constants/ :

1. app_colors.dart
   - Classe AppColors avec des const static
   - primary: Color(0xFF1A1A2E)
   - accent: Color(0xFFF4A61D)      // montants, CTA
   - success: Color(0xFF2ECC71)     // solde OK
   - warning: Color(0xFFF39C12)     // solde faible
   - danger: Color(0xFFE74C3C)      // solde vide, erreur
   - surface: Color(0xFFFFFFFF)
   - background: Color(0xFFF5F6FA)
   - textPrimary: Color(0xFF1A1A2E)
   - textSecondary: Color(0xFF7F8C8D)
   - cardBorder: Color(0xFFE8ECF4)

2. app_spacing.dart
   - Classe AppSpacing avec des const static double
   - xs: 4.0, sm: 8.0, md: 16.0, lg: 24.0, xl: 32.0, xxl: 48.0

3. app_text_styles.dart
   - Classe AppTextStyles avec des const static TextStyle
   - displayLarge: 32px, DM Sans, w700, textPrimary
   - titleLarge: 20px, DM Sans, w600, textPrimary
   - titleMedium: 17px, DM Sans, w500, textPrimary
   - bodyLarge: 16px, DM Sans, w400, textPrimary
   - bodyMedium: 14px, DM Sans, w400, textSecondary
   - caption: 13px, DM Sans, w400, textSecondary
   - amount: 28px, DM Mono ou Roboto Mono, w700, textPrimary
     (pour les montants FCFA)
   - amountSmall: 18px, DM Mono, w500, textPrimary

4. api_constants.dart
   - Classe ApiConstants
   - baseUrl depuis flutter_dotenv: Env.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1'
   - connectTimeout: 30000 ms
   - receiveTimeout: 30000 ms
   - Endpoints Phase 2:
     static const dashboardSummary = '/dashboard/summary/';
     static const sims = '/sims/';
     static const alerts = '/alerts/';

Contraintes :
- Utiliser const partout où possible
- Pas de magic values — tout dans ces fichiers
- Pas de dépendances Flutter UI dans app_colors, app_spacing
  (juste dart:ui pour Color)
- Inclure les imports nécessaires
```

**Résultat attendu :**
- [ ] 4 fichiers créés dans `lib/core/constants/`
- [ ] Pas d'erreurs `flutter analyze`
- [ ] Les couleurs reflètent le style fintech SIC

---

### Prompt 0.2 — ThemeData Flutter

```
En utilisant les constantes créées dans app_colors.dart et app_text_styles.dart,
crée lib/core/constants/app_theme.dart.

Exigences :
- Classe AppTheme avec static ThemeData lightTheme
- MaterialApp theme complet : colorScheme, textTheme, appBarTheme,
  cardTheme, elevatedButtonTheme, inputDecorationTheme, bottomSheetTheme
- colorScheme.primary = AppColors.primary
- colorScheme.secondary = AppColors.accent
- AppBar : fond blanc, titre textPrimary, élévation 0, ombre subtile
- Cards : fond surface, radius 12.0, pas d'ombre (bordure cardBorder 1px)
- ElevatedButton : fond primary, texte blanc, radius 8.0, hauteur 52px
- InputDecoration : fond background, bordure cardBorder, radius 8.0,
  focus bordure primary
- BottomSheet : fond surface, radius top 20.0

Contraintes :
- Utiliser uniquement Material 3 (useMaterial3: true)
- Pas de couleurs hardcodées — tout depuis AppColors
- Inclure un commentaire sur chaque section du thème
```

**Résultat attendu :**
- [ ] `app_theme.dart` créé
- [ ] L'app a un look cohérent fintech après `theme: AppTheme.lightTheme`

---

### Prompt 0.3 — Gestion des erreurs (Failures)

```
Crée le système de gestion d'erreurs dans lib/core/errors/ pour une app
fintech Flutter suivant la Clean Architecture.

1. lib/core/errors/failures.dart
   Classe abstraite Failure extends Equatable
   Sous-classes :
   - ServerFailure(String message, int? statusCode)
   - NetworkFailure()          // pas de connexion
   - CacheFailure(String message)
   - AuthFailure()             // token expiré
   - ValidationFailure(String message)
   - NotFoundFailure()

2. lib/core/errors/exceptions.dart
   Exceptions techniques (lancées dans Data, converties en Failure dans Repository) :
   - ServerException(String message, int statusCode)
   - NetworkException()
   - CacheException(String message)
   - AuthException()

3. lib/core/usecases/usecase.dart
   - Interface abstraite UseCase<Type, Params>
   - Méthode call(Params params) retourne Future<Either<Failure, Type>>
   - Classe NoParams extends Equatable (pour les UseCases sans paramètre)

Contraintes :
- Utiliser le package dartz (Either, Unit)
- Utiliser le package equatable (props)
- Chaque Failure a un message String lisible pour l'affichage utilisateur
- Pas de print() — utiliser debugPrint() si nécessaire
```

**Résultat attendu :**
- [ ] Système d'erreurs complet
- [ ] `flutter analyze` sans erreur

---

### Prompt 0.4 — Utilitaires FCFA et dates

```
Crée les utilitaires dans lib/core/utils/ pour l'app SIC (Afrique de l'Ouest,
monnaie FCFA, langue française).

1. lib/core/utils/fcfa_formatter.dart
   Classe FcfaFormatter :
   - static String format(double amount)
     75000.0 → "75 000 FCFA"
     1250000.0 → "1 250 000 FCFA"
     500.0 → "500 FCFA"
   - static String formatCompact(double amount)
     1250000.0 → "1,25M FCFA"
     75000.0 → "75K FCFA"
   - static String formatBenefit(double amount)
     Préfixe + vert si positif, rouge si négatif : "+ 12 500 FCFA"
   Utiliser le package intl (NumberFormat)

2. lib/core/utils/date_formatter.dart
   Classe DateFormatter :
   - static String formatFull(DateTime date)
     → "15 jan. 2024 à 14h30"
   - static String formatDate(DateTime date)
     → "15 jan. 2024"
   - static String formatRelative(DateTime date)
     → "Il y a 5 min" / "Il y a 2h" / "Hier" / date si > 2 jours
   Utiliser le package intl, locale 'fr_FR'

3. lib/core/utils/validators.dart
   Classe Validators :
   - static String? validatePhone(String? value)
     Format Afrique Ouest : commence par 05, 07, 01 etc., 10 chiffres
   - static String? validateAmount(String? value)
     Minimum 100 FCFA, maximum 2 000 000 FCFA, entier ou décimal
   - static String? validateRequired(String? value, String fieldName)

Contraintes :
- Méthodes toutes static
- Retourner null si valide, String message si invalide (pour Form validators)
- Tests unitaires dans test/core/utils/ pour chaque méthode
```

**Résultat attendu :**
- [ ] 3 fichiers utilitaires créés
- [ ] Tests unitaires qui passent
- [ ] `75000.0` formaté en `"75 000 FCFA"`

---

### Prompt 0.5 — Widgets globaux réutilisables

```
Crée les widgets globaux dans lib/core/widgets/ pour l'app SIC.
Utiliser les constantes AppColors, AppSpacing, AppTextStyles déjà créées.

1. sic_button.dart — SicButton
   Paramètres : label, onPressed, isLoading (bool), variant (primary/secondary/ghost)
   - primary : fond AppColors.primary, texte blanc, hauteur 52px, radius 8
   - secondary : fond transparent, bordure primary, texte primary
   - ghost : fond transparent, pas de bordure, texte primary
   - isLoading : remplace le texte par un CircularProgressIndicator blanc (18px)
   - Disabled si onPressed == null ou isLoading

2. sic_loading.dart — SicLoading
   Indicateur de chargement centré avec le logo SIC
   - CircularProgressIndicator couleur accent
   - Texte optionnel "Chargement..." en caption

3. sic_error_widget.dart — SicErrorWidget
   Affichage d'erreur avec retry
   Paramètres : error (Object), onRetry (VoidCallback?)
   - Icône d'erreur (Icons.error_outline)
   - Message d'erreur lisible (mapper les Failure en messages FR)
   - Bouton "Réessayer" si onRetry != null

4. sic_amount_display.dart — SicAmountDisplay
   Affichage d'un montant FCFA stylé
   Paramètres : amount (double), size (large/medium/small), color (Color?)
   - Utiliser FcfaFormatter.format()
   - Utiliser AppTextStyles.amount / amountSmall selon size
   - Couleur par défaut textPrimary, personnalisable

5. operator_logo.dart — OperatorLogo
   Affiche le logo/badge d'un opérateur
   Paramètres : operatorCode (String), size (double)
   - 'OM' → fond orange #FF6600, texte "OM" blanc
   - 'MOOV' → fond bleu #0066CC, texte "MV" blanc
   - 'TELECEL' → fond vert #009933, texte "TC" blanc
   - 'MTN' → fond jaune #FFCC00, texte "MTN" noir
   - Fallback : fond gris, texte 2 premières lettres du code
   - Forme : cercle ou rounded square selon un paramètre shape

Contraintes :
- Tous les widgets avec const constructors
- Paramètres optionnels avec valeurs par défaut sensées
- Pas de logique métier dans les widgets
- Accessibilité : Semantics widget pour les éléments interactifs
```

**Résultat attendu :**
- [ ] 5 widgets réutilisables créés
- [ ] `flutter analyze` sans erreur
- [ ] Les widgets s'affichent correctement sur l'émulateur

---

**Commit étape 0 :**
```
git add .
git commit -m "feat(core): add theme, errors, utils and shared widgets"
```

---

## ÉTAPE 1 — Feature Dashboard (Domain + Data)

**Objectif :** Créer le métier et les données mockées du Dashboard.
**Durée estimée :** 2-3 heures
**Branche :** `feature/phase2-dashboard`

---

### Prompt 1.1 — Entités et Repository (Domain)

```
Crée la couche Domain de la feature Dashboard dans
lib/features/dashboard/domain/ pour l'app SIC Mobile.

Contexte :
- L'agent PDV a plusieurs puces (SIM) Mobile Money
- Le Dashboard montre le solde total agrégé + soldes par opérateur
- Les bénéfices sont calculés par SIC : 0.07% de chaque transaction
- Clean Architecture : Domain ne dépend de rien (pur Dart)

1. domain/entities/balance_summary.dart
   BalanceSummary (extends Equatable) :
   - operatorCode: String      ('OM', 'MOOV', 'TELECEL')
   - operatorName: String
   - balance: double
   - isLow: bool               (balance < alertThreshold)
   - alertThreshold: double
   - lastUpdated: DateTime

2. domain/entities/benefit_period.dart
   BenefitPeriod (extends Equatable) :
   - today: double
   - week: double
   - month: double
   - total: double

3. domain/entities/agent_summary.dart
   AgentSummary (extends Equatable) :
   - agentCode: String
   - agentName: String
   - totalBalance: double      (somme de tous les balances)
   - benefits: BenefitPeriod
   - balances: List<BalanceSummary>
   - transactionCountToday: int

4. domain/repositories/dashboard_repository.dart
   Interface abstraite DashboardRepository :
   - Future<Either<Failure, AgentSummary>> getDashboardSummary()
   - Future<Either<Failure, Unit>> refreshBalance(String operatorCode)

5. domain/usecases/get_dashboard_summary.dart
   GetDashboardSummary implements UseCase<AgentSummary, NoParams>

6. domain/usecases/refresh_balance.dart
   Params : RefreshBalanceParams(String operatorCode) extends Equatable
   RefreshBalance implements UseCase<Unit, RefreshBalanceParams>

Contraintes :
- Utiliser dartz (Either, Unit)
- Utiliser equatable (props liste complète)
- Aucun import Flutter — pur Dart
- Constructeurs const partout où possible
```

**Résultat attendu :**
- [ ] 6 fichiers domain créés
- [ ] Zéro import Flutter dans domain/
- [ ] `flutter analyze` sans erreur

---

### Prompt 1.2 — Mock Data et Repository (Data)

```
Crée la couche Data de la feature Dashboard dans
lib/features/dashboard/data/ pour l'app SIC Mobile.
Le backend Django n'est pas encore disponible — utiliser des mocks.

1. data/models/balance_summary_model.dart
   BalanceSummaryModel extends BalanceSummary :
   - factory fromJson(Map<String, dynamic> json)
   - Map<String, dynamic> toJson()
   - factory mock(String operatorCode) pour les tests

2. data/models/agent_summary_model.dart
   AgentSummaryModel extends AgentSummary :
   - factory fromJson(Map<String, dynamic> json)
   - Map<String, dynamic> toJson()
   - factory mock() retourne des données réalistes :
     agentCode: 'AGT-0042', agentName: 'Koné Moussa',
     balances: [OM 250000, MOOV 85000, TELECEL 150000],
     benefits: today 12500, week 87300, month 312000, total 1250000,
     transactionCountToday: 8

3. data/datasources/dashboard_local_datasource.dart
   DashboardLocalDatasource (classe concrète) :
   - Future<AgentSummaryModel> getDashboardSummary()
     → await Future.delayed(800ms) puis retourne AgentSummaryModel.mock()
   - Future<void> refreshBalance(String operatorCode)
     → await Future.delayed(500ms) puis simule succès

4. data/datasources/dashboard_remote_datasource.dart
   DashboardRemoteDatasource (classe concrète, COMMENTÉE pour l'instant) :
   - Même interface que local
   - Contient le code Dio pour les vrais appels API
   - Endpoint : GET /dashboard/summary/
   - Tout le code présent mais commenté avec // TODO: uncomment when backend ready

5. data/repositories/dashboard_repository_impl.dart
   DashboardRepositoryImpl implements DashboardRepository :
   - Injecte DashboardLocalDatasource (via constructeur)
   - getDashboardSummary() : try/catch → Left(ServerFailure) ou Right(model)
   - refreshBalance() : idem

Contraintes :
- Les models ont les mêmes propriétés que les entités + JSON
- Le mock data est réaliste (vrais noms d'opérateurs, vrais montants FCFA)
- Le remote datasource est présent mais entièrement commenté
- Gestion des exceptions → Failures dans le Repository
```

**Résultat attendu :**
- [ ] 5 fichiers data créés
- [ ] Mock retourne des données cohérentes avec le cahier des charges
- [ ] Remote datasource présent et commenté pour future utilisation

---

**Commit étape 1 :**
```
git add .
git commit -m "feat(dashboard): add domain entities, usecases and mock data"
```

---

## ÉTAPE 2 — Feature Dashboard (Presentation)

**Objectif :** Créer l'UI du Dashboard avec Riverpod et flutter_animate.
**Durée estimée :** 3-4 heures

---

### Prompt 2.1 — Provider Riverpod Dashboard

```
Crée lib/features/dashboard/presentation/providers/dashboard_provider.dart
pour l'app SIC Mobile avec Riverpod 2.x (riverpod_annotation).

Contexte :
- Utiliser @riverpod avec code generation (riverpod_annotation)
- DashboardNotifier extends AsyncNotifier<AgentSummary>
- L'état peut être : loading / error / data

Crée :
1. dashboardNotifierProvider — AsyncNotifier<AgentSummary>
   - build() appelle GetDashboardSummary usecase
   - refresh() méthode publique pour pull-to-refresh
   - Gère les Failures : throw l'exception pour que .when(error:...) la catchent

2. selectedBenefitPeriodProvider — StateProvider<BenefitPeriod>
   Valeurs : 'today' | 'week' | 'month'
   Défaut : 'today'
   (pour les chips bénéfices sur le Dashboard)

3. Providers de dépendances (chaîne d'injection) :
   - dashboardLocalDatasourceProvider
   - dashboardRepositoryProvider
   - getDashboardSummaryProvider
   - refreshBalanceProvider

Contraintes :
- Utiliser riverpod_annotation (@riverpod) pas l'ancienne API
- Lancer dart run build_runner build après création
- Pas de logique dans les providers — déléguer aux UseCases
- Les erreurs sont des Failure, pas des String
```

**Résultat attendu :**
- [ ] Provider créé
- [ ] `build_runner build` sans erreur
- [ ] Fichier `.g.dart` généré

---

### Prompt 2.2 — Widgets Dashboard

```
Crée les widgets dans lib/features/dashboard/presentation/widgets/
pour l'app SIC Mobile.

Style visuel : fintech africain, clean, soft UI
- Fond app : AppColors.background (#F5F6FA)
- Cards : fond blanc, radius 12, bordure légère AppColors.cardBorder
- Montants : police monospace, AppColors.accent pour le solde total
- Statuts solde : vert (OK), orange (faible), rouge (vide)

1. balance_card.dart — BalanceCard
   Widget pour une puce/solde d'opérateur :
   - OperatorLogo (cercle coloré) à gauche
   - Nom opérateur + numéro (masqué : 07***456)
   - Solde formaté en FCFA à droite (FcfaFormatter)
   - Indicateur statut : point vert/orange/rouge
   - Largeur fixe 200px (pour liste horizontale scrollable)
   - Bordure orange si isLow, fond rouge très léger si balance == 0
   - onTap : ouvre BalanceUpdateBottomSheet (callback)

2. benefit_chips.dart — BenefitChips
   3 chips sélectionnables : Aujourd'hui / Semaine / Mois
   - Chip sélectionné : fond primary, texte blanc
   - Chip non sélectionné : fond transparent, texte textSecondary
   - Consomme selectedBenefitPeriodProvider (Riverpod)
   - Animation smooth entre les sélections

3. benefit_summary_widget.dart — BenefitSummaryWidget
   Affiche le bénéfice pour la période sélectionnée :
   - Gros montant centré avec AppTextStyles.amount
   - Couleur AppColors.success (toujours positif en Phase 2)
   - Label "Bénéfices [période]" en caption

4. quick_actions_row.dart — QuickActionsRow
   4 boutons action en rangée horizontale :
   - Dépôt (icon: arrow_down_circle, couleur success)
   - Retrait (icon: arrow_up_circle, couleur warning)
   - Transfert (icon: swap_horiz, couleur primary)
   - Recharge (icon: phone_android, couleur accent)
   - Chaque bouton : icône + label, tap feedback scale 0.95
   - onTap : callback (navigation Phase 3)

Contraintes :
- Tous les widgets avec const constructors
- Utiliser flutter_animate pour les micro-animations (fade, scale)
- Tap sur BalanceCard : HapticFeedback.lightImpact()
- Pas d'état local dans les widgets — tout via providers ou callbacks
```

**Résultat attendu :**
- [ ] 4 widgets créés avec le style SIC
- [ ] Affichage cohérent sur émulateur

---

### Prompt 2.3 — Écran Dashboard principal

```
Crée lib/features/dashboard/presentation/screens/dashboard_screen.dart
pour l'app SIC Mobile.

C'est l'écran principal de l'app — premier écran après login.

Structure de l'écran (de haut en bas) :

1. AppBar personnalisée :
   - Gauche : avatar agent (initiales dans cercle primary)
   - Centre : "Bonjour, [Prénom]" en titleMedium
   - Droite : icône cloche notifications + icône settings

2. Section solde total :
   - Label "Solde total" en caption textSecondary
   - Montant total en AppTextStyles.amount AppColors.accent
   - Animation counter avec flutter_animate : 0 → valeur réelle en 600ms
   - Sous le montant : "[N] puces actives" en caption

3. Section soldes par puce :
   - Label "Mes soldes" + bouton "Gérer" (navigation SimManagement)
   - ListView horizontal des BalanceCard
   - Si alerte solde faible → bannière rouge en haut avec message

4. Section bénéfices :
   - Label "Bénéfices" en titleMedium
   - BenefitChips (Aujourd'hui / Semaine / Mois)
   - BenefitSummaryWidget (montant de la période sélectionnée)

5. Section actions rapides :
   - Label "Actions rapides" en titleMedium
   - QuickActionsRow

6. Pull-to-refresh sur toute la page (RefreshIndicator)

Gestion des états :
- loading → SicLoading() centré
- error → SicErrorWidget avec retry
- data → affichage normal

Contraintes :
- ConsumerWidget (Riverpod)
- Utiliser ref.watch(dashboardNotifierProvider)
- SafeArea en haut et en bas
- SingleChildScrollView pour scroller si petit écran
- Pas de Navigator.push direct — utiliser context.go('/...') de go_router
- Padding horizontal : AppSpacing.md (16px) partout
```

**Résultat attendu :**
- [ ] Dashboard complet et fonctionnel avec données mockées
- [ ] Animation counter sur le solde total
- [ ] Pull-to-refresh fonctionne
- [ ] Gestion loading/error/data

---

**Commit étape 2 :**
```
git add .
git commit -m "feat(dashboard): complete dashboard screen with Riverpod and animations"
```

---

## ÉTAPE 3 — Feature Gestion des Puces

**Objectif :** CRUD des SIM avec swipe actions et BottomSheet d'ajout.
**Durée estimée :** 3 heures

### Prompt 3.1 — Domain + Data SIM

```
Crée la feature sim_management complète (Domain + Data) dans
lib/features/sim_management/ pour l'app SIC Mobile.

Même pattern que Dashboard (étapes 1.1 et 1.2).

Entité SimCard :
- id: String
- operatorCode: String
- operatorName: String
- phoneNumber: String
- balance: double
- isActive: bool
- alertThreshold: double
- addedAt: DateTime

UseCases :
- GetSims → List<SimCard>
- AddSim → params: AddSimParams(operatorCode, phoneNumber)
- ToggleSim → params: ToggleSimParams(id, isActive)
- UpdateSimThreshold → params: UpdateThresholdParams(id, threshold)

Mock data : 3 SIM (OM, MOOV, TELECEL) avec numéros et soldes réalistes.
Opérateurs disponibles hardcodés dans le datasource :
[OM, MOOV, TELECEL, MTN, WAVE, CORIS]

Même structure que Dashboard pour Data (local mock + remote commenté).
```

### Prompt 3.2 — UI Gestion des Puces

```
Crée l'écran et les widgets sim_management dans
lib/features/sim_management/presentation/ pour l'app SIC Mobile.

1. sim_card_tile.dart :
   - Tile avec OperatorLogo, nom opérateur, numéro masqué, solde, statut
   - Swipe left (Dismissible ou flutter_slidable) :
     → bouton rouge Désactiver / bouton bleu Modifier
   - Puce désactivée : opacité 0.5, badge "Inactif"

2. operator_selector.dart :
   - Grid de sélection d'opérateur (2 colonnes)
   - Chaque opérateur : OperatorLogo + nom
   - Sélectionné : bordure primary

3. add_sim_bottom_sheet.dart :
   - OperatorSelector en haut
   - Champ numéro de téléphone (validator depuis Validators)
   - Bouton Enregistrer (SicButton primary)
   - showModalBottomSheet avec radius 20

4. sim_management_screen.dart :
   - AppBar "Mes puces"
   - ListView des SimCardTile
   - FAB + pour ouvrir AddSimBottomSheet
   - Confirmation Dialog avant désactivation
   - État vide : illustration simple + "Ajoutez votre première puce"

Contraintes identiques aux autres écrans.
```

**Commit étape 3 :**
```
git add .
git commit -m "feat(sim): complete SIM management screen with CRUD"
```

---

## ÉTAPE 4 — Balance Update BottomSheet

**Objectif :** BottomSheet de mise à jour de solde depuis le Dashboard.
**Durée estimée :** 1.5 heure

### Prompt 4.1 — Balance Update

```
Crée la feature balance_update dans lib/features/balance_update/
pour l'app SIC Mobile.

C'est un BottomSheet (pas un écran), accessible depuis le Dashboard
quand l'agent tape sur une BalanceCard.

Domain :
- Entity BalanceUpdate : simId, previousBalance, newBalance, updatedAt
- UseCase UpdateBalance : params UpdateBalanceParams(simId, newBalance)

Data : mock local qui met à jour la balance dans une liste en mémoire

Presentation :
- balance_update_provider.dart : AsyncNotifier
- balance_update_bottom_sheet.dart :
  - Titre "Mettre à jour le solde [OM]"
  - Solde actuel affiché en grand (grisé)
  - Champ nouveau solde avec clavier numérique
  - Historique 3 dernières mises à jour (liste compact)
  - Bouton Confirmer → HapticFeedback.mediumImpact() → ferme BottomSheet
  - Met à jour le DashboardNotifier après confirmation

Contraintes :
- Après update : invalider dashboardNotifierProvider pour refresh auto
- Utiliser ref.invalidate(dashboardNotifierProvider) depuis Riverpod
- Animation slide-up native du BottomSheet (showModalBottomSheet)
```

**Commit étape 4 :**
```
git add .
git commit -m "feat(balance): add balance update bottom sheet"
```

---

## ÉTAPE 5 — Feature Alertes + Navigation go_router

**Objectif :** Écran alertes et navigation complète Phase 2.
**Durée estimée :** 2 heures

### Prompt 5.1 — Alertes Solde

```
Crée la feature alerts dans lib/features/alerts/ pour l'app SIC Mobile.

Domain :
- Entity AlertConfig : operatorCode, isEnabled, threshold, lastUpdated
- UseCases : GetAlertConfigs, SaveAlertConfig

Data :
- Local datasource avec persistance Hive (pas juste en mémoire)
- Hive box name : 'alert_configs'
- Clé : operatorCode, valeur : AlertConfigModel sérialisé

Presentation :
- alert_config_tile.dart : Toggle switch + slider threshold + preview text
- alerts_screen.dart : liste des AlertConfigTile par opérateur

Points importants :
- Sauvegarde Hive à chaque modification (debounce 500ms avec Timer)
- Les configs persistent entre les redémarrages de l'app
- Preview dynamique : "Alerte si solde [OM] < [X] FCFA"
```

### Prompt 5.2 — Navigation go_router complète

```
Configure go_router pour la Phase 2 de SIC Mobile dans lib/core/router/app_router.dart.

Routes :
- / → redirect vers /dashboard
- /dashboard → DashboardScreen
- /dashboard/sims → SimManagementScreen
- /dashboard/alerts → AlertsScreen
- /splash → SplashScreen (simple, pour plus tard)

Crée un AppRouter avec :
- Provider Riverpod : appRouterProvider
- ShellRoute pour la navigation avec BottomNavigationBar Phase 2 :
  - Onglet 1 : Dashboard (icon: home)
  - Onglet 2 : Puces (icon: sim_card)
  - Onglet 3 : Alertes (icon: notifications)

BottomNavigationBar style SIC :
- Fond blanc, selectedItem primary, unselected textSecondary
- Labels en français

Contraintes :
- go_router 13.x
- Pas de Navigator.of(context).push direct nulle part
- Utiliser context.go() et context.push() partout
```

**Commit étape 5 :**
```
git add .
git commit -m "feat(alerts): add alerts screen with Hive persistence"
git commit -m "feat(router): configure go_router with bottom nav Phase 2"
```

---

## ÉTAPE 6 — Tests unitaires Phase 2

**Objectif :** Au moins 1 test par UseCase.
**Durée estimée :** 2 heures

### Prompt 6.1 — Tests UseCases

```
Crée les tests unitaires pour tous les UseCases de la Phase 2
dans test/features/ pour l'app SIC Mobile.

Pour chaque UseCase, 3 tests minimum :
1. "should return [Entity] when repository call is successful"
2. "should return Failure when repository throws exception"
3. Test du cas spécifique au UseCase

Utiliser mockito pour mocker les repositories.

UseCases à tester :
- GetDashboardSummary
- RefreshBalance
- GetSims
- AddSim
- ToggleSim
- UpdateBalance
- GetAlertConfigs
- SaveAlertConfig

Structure des tests : AAA (Arrange, Act, Assert)
Nommage : 'should [expected] when [condition]'
```

**Commit étape 6 :**
```
git add .
git commit -m "test: add unit tests for all Phase 2 usecases"
```

---

## ÉTAPE 7 — Validation et PR vers develop

**Objectif :** S'assurer que tout est propre avant de merger.

### Checklist finale Phase 2

```powershell
# 1. Analyse statique — doit être 0 erreur, 0 warning
flutter analyze

# 2. Tests — doivent tous passer
flutter test

# 3. Build runner — fichiers générés à jour
dart run build_runner build --delete-conflicting-outputs

# 4. Vérifier sur émulateur
flutter run

# 5. Vérifier les 4 écrans accessibles
# 6. Pull-to-refresh Dashboard fonctionne
# 7. Ajout puce → apparaît dans la liste
# 8. Mise à jour solde → Dashboard se rafraîchit
# 9. Alertes persistent après hot restart (Ctrl+Shift+F5)
```

**Commit final + PR :**
```
git add .
git commit -m "chore: phase 2 complete - ready for review"
git push origin feature/phase2-dashboard
# → Ouvrir Pull Request sur GitHub vers develop
# → Titre PR : "feat: Phase 2 Dashboard & Gestion des Puces"
# → Description : liste les 4 écrans livrés + screenshots
```
