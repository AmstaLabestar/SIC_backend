# Phase 2 — Dashboard & Gestion des Puces

**Durée estimée :** 8 semaines (semaines 6 à 13 du projet global)
**Branche de travail :** `develop` → `feature/phase2-*`
**Backend :** non disponible en Phase 2 — on utilise des mocks locaux

---

## Objectif global de la Phase 2

Livrer 4 écrans fonctionnels avec données mockées, prêts à être branchés sur l'API Django sans refactoring :

1. **Dashboard Principal** — vue agrégée des soldes et bénéfices
2. **Gestion des Puces** — CRUD des SIM par opérateur
3. **Mise à jour Solde** — saisie manuelle après opération
4. **Alertes Solde** — configuration des seuils d'alerte

À la fin de la Phase 2 : un agent PDV peut voir tous ses soldes, gérer ses puces, mettre à jour un solde manuellement et configurer ses alertes. L'app est utilisable sans backend.

---

## Architecture mise en place avant les écrans

Avant de coder le premier écran, les fondations `core/` doivent être en place.

### core/ — ce qu'il faut créer

**Thème SIC (`core/constants/`)**

```
app_colors.dart       Palette fintech SIC
app_text_styles.dart  Typographie (titre, corps, caption, montant)
app_spacing.dart      Constantes d'espacement (xs, sm, md, lg, xl)
app_theme.dart        ThemeData Flutter complet (light + dark préparé)
api_constants.dart    Base URL, timeouts, endpoints Phase 2
```

**Palette couleurs SIC :**
| Nom | Hex | Usage |
|---|---|---|
| `primary` | `#1A1A2E` | Fond principal, texte important |
| `accent` | `#F4A61D` | CTA, montants, highlights |
| `success` | `#2ECC71` | Solde suffisant, confirmation |
| `warning` | `#F39C12` | Solde faible |
| `danger` | `#E74C3C` | Solde vide, erreur |
| `surface` | `#FFFFFF` | Fond des cards |
| `background` | `#F5F6FA` | Fond de l'app |
| `textPrimary` | `#1A1A2E` | Texte principal |
| `textSecondary` | `#7F8C8D` | Labels, sous-titres |

**Typographie SIC :**
- Police principale : `DM Sans` (Google Fonts — propre, lisible, moderne)
- Montants : `DM Mono` ou `Roboto Mono` (alignement chiffres)
- Tailles : display (32px), title (20px), body (16px), caption (13px)

**Widgets globaux (`core/widgets/`)**

```
sic_button.dart           Bouton primaire / secondaire / ghost SIC
sic_text_field.dart       Champ texte avec style SIC
sic_loading.dart          Indicateur de chargement
sic_error_widget.dart     État d'erreur avec retry
sic_amount_display.dart   Affichage montant FCFA formaté
operator_logo.dart        Logo opérateur (OM, Moov, Telecel) depuis assets
```

**Utilitaires (`core/utils/`)**

```
fcfa_formatter.dart    75000 → "75 000 FCFA"
date_formatter.dart    2024-01-15 → "15 jan. 2024 à 14h30"
validators.dart        Validation numéro téléphone, montant, etc.
```

---

## Écran 1 — Dashboard Principal

**Fichiers concernés :**
```
features/dashboard/
├── domain/entities/agent_summary.dart
├── domain/entities/balance_summary.dart
├── domain/entities/benefit_summary.dart
├── domain/repositories/dashboard_repository.dart
├── domain/usecases/get_dashboard_summary.dart
├── data/models/agent_summary_model.dart
├── data/models/balance_summary_model.dart
├── data/datasources/dashboard_local_datasource.dart
├── data/repositories/dashboard_repository_impl.dart
├── presentation/providers/dashboard_provider.dart
├── presentation/screens/dashboard_screen.dart
└── presentation/widgets/
    ├── balance_card.dart
    ├── operator_chip.dart
    ├── benefit_summary_widget.dart
    └── quick_actions_row.dart
```

**Données mockées à prévoir :**
```dart
AgentSummary(
  agentName: "Koné Moussa",
  agentCode: "AGT-0042",
  totalBalance: 485000.0,   // somme de tous les soldes
  todayBenefits: 12500.0,
  weekBenefits: 87300.0,
  monthBenefits: 312000.0,
  balances: [
    BalanceSummary(operatorCode: 'OM',     operatorName: 'Orange Money',  balance: 250000, isLow: false),
    BalanceSummary(operatorCode: 'MOOV',   operatorName: 'Moov Money',    balance: 85000,  isLow: false),
    BalanceSummary(operatorCode: 'TELECEL',operatorName: 'Telecel Money', balance: 150000, isLow: false),
  ]
)
```

**UX à respecter :**
- Solde total en grand au centre en haut → animation counter 0 → valeur (600ms)
- Cards soldes par opérateur → scroll horizontal
- Card solde faible → bordure orange + icône alerte
- Card solde vide → fond rouge léger + badge "Vide"
- Bénéfices : 3 chips (Aujourd'hui / Semaine / Mois), tap pour switcher
- 4 boutons raccourci en bas : Dépôt, Retrait, Transfert, Recharge
- Pull-to-refresh → relance le mock avec délai simulé

---

## Écran 2 — Gestion des Puces

**Fichiers concernés :**
```
features/sim_management/
├── domain/entities/sim_card.dart
├── domain/repositories/sim_repository.dart
├── domain/usecases/get_sims.dart
├── domain/usecases/add_sim.dart
├── domain/usecases/update_sim.dart
├── domain/usecases/toggle_sim.dart
├── data/models/sim_card_model.dart
├── data/datasources/sim_local_datasource.dart
├── data/repositories/sim_repository_impl.dart
├── presentation/providers/sim_provider.dart
├── presentation/screens/sim_management_screen.dart
└── presentation/widgets/
    ├── sim_card_tile.dart
    ├── add_sim_bottom_sheet.dart
    └── operator_selector.dart
```

**Entité SimCard :**
```dart
SimCard(
  id: "sim_001",
  operatorCode: "OM",           // 'OM' | 'MOOV' | 'TELECEL' | 'MTN'
  operatorName: "Orange Money",
  phoneNumber: "0701234567",
  balance: 250000.0,
  isActive: true,
  alertThreshold: 50000.0,      // alerte si balance < seuil
  addedAt: DateTime(2024, 1, 10),
)
```

**UX à respecter :**
- Liste des puces avec statut visuel (OK vert / Faible orange / Vide rouge)
- Swipe left sur une puce → bouton Désactiver (rouge) + Modifier (bleu)
- FAB `+` en bas à droite → BottomSheet d'ajout
- BottomSheet ajout : sélecteur opérateur par logo + champ numéro
- Confirmation modale avant désactivation (puce active = argent en jeu)
- Puce désactivée : apparence grisée, toujours visible mais inopérable

---

## Écran 3 — Mise à jour Solde

**Fichiers concernés :**
```
features/balance_update/
├── domain/entities/balance_update.dart
├── domain/repositories/balance_repository.dart
├── domain/usecases/update_balance.dart
├── data/models/balance_update_model.dart
├── data/datasources/balance_local_datasource.dart
├── data/repositories/balance_repository_impl.dart
├── presentation/providers/balance_update_provider.dart
└── presentation/widgets/
    └── balance_update_bottom_sheet.dart    # Pas d'écran dédié — BottomSheet
```

**UX à respecter :**
- Accessible depuis : tap sur une card de solde dans le Dashboard
- BottomSheet animé slide-up (pas navigation vers un nouvel écran)
- Afficher : solde actuel / champ nouveau solde / bouton Confirmer
- Clavier numérique custom ou `keyboardType: TextInputType.number`
- Feedback haptic sur confirmation (`HapticFeedback.mediumImpact()`)
- Après confirmation : ferme le BottomSheet + met à jour la card en temps réel
- Historique des 3 dernières mises à jour visibles dans le BottomSheet

---

## Écran 4 — Configuration Alertes Solde

**Fichiers concernés :**
```
features/alerts/
├── domain/entities/alert_config.dart
├── domain/repositories/alert_repository.dart
├── domain/usecases/get_alert_configs.dart
├── domain/usecases/save_alert_config.dart
├── data/models/alert_config_model.dart
├── data/datasources/alert_local_datasource.dart
├── data/repositories/alert_repository_impl.dart
├── presentation/providers/alert_provider.dart
├── presentation/screens/alerts_screen.dart
└── presentation/widgets/
    ├── alert_config_tile.dart
    └── threshold_slider.dart
```

**Entité AlertConfig :**
```dart
AlertConfig(
  operatorCode: "OM",
  isEnabled: true,
  threshold: 50000.0,     // Alerter si solde < 50 000 FCFA
  lastUpdated: DateTime.now(),
)
```

**UX à respecter :**
- Une ligne par opérateur enregistré
- Toggle switch gauche (activer/désactiver l'alerte)
- Slider ou champ texte pour le montant seuil
- Preview texte : "Vous serez alerté si solde OM < 50 000 FCFA"
- Sauvegarde automatique à chaque modification (debounce 500ms)
- Sauvegarde dans Hive (persistance locale offline)

---

## Navigation Phase 2

```
go_router routes à configurer :

/dashboard              → DashboardScreen
/sims                   → SimManagementScreen
/alerts                 → AlertsScreen

# BottomSheets (pas de route — lancées depuis le widget)
BalanceUpdateBottomSheet   → depuis DashboardScreen tap sur card solde
AddSimBottomSheet          → depuis SimManagementScreen FAB +
```

---

## Critères de validation Phase 2

La phase est terminée quand :

- [ ] Les 4 écrans sont accessibles via go_router
- [ ] Les données mockées s'affichent correctement sur tous les écrans
- [ ] Le pull-to-refresh fonctionne sur le Dashboard
- [ ] L'ajout d'une puce fonctionne (s'affiche dans la liste)
- [ ] La désactivation d'une puce fonctionne avec confirmation
- [ ] La mise à jour d'un solde met à jour la card Dashboard en temps réel
- [ ] Les alertes sont sauvegardées localement (persistent après redémarrage)
- [ ] `flutter analyze` : 0 erreurs, 0 warnings
- [ ] Au moins 1 test unitaire par UseCase (minimum 8 tests)
- [ ] Testé sur émulateur Android + vrai appareil si possible
- [ ] Les providers sont prêts pour basculer sur l'API réelle (datasource remote en place mais commentée)
