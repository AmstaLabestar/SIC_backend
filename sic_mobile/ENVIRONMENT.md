# Configuration de l'environnement — Windows + VS Code

## Pré-requis (à vérifier avant tout)

Ouvre un terminal PowerShell et vérifie :

```powershell
flutter --version      # Doit afficher Flutter 3.x
dart --version         # Doit afficher Dart 3.x
git --version          # Doit afficher git 2.x+
code --version         # Doit afficher VS Code
```

Si `flutter doctor` affiche des warnings, les corriger avant de continuer.

---

## 1. Extensions VS Code obligatoires

Ouvrir VS Code → `Ctrl+Shift+X` → installer :

| Extension | ID | Rôle |
|---|---|---|
| Flutter | `Dart-Code.flutter` | Support Flutter complet |
| Dart | `Dart-Code.dart-code` | Langage Dart |
| Riverpod Snippets | `robert-brunhage.flutter-riverpod-snippets` | Snippets Riverpod |
| Error Lens | `usernamehw.errorlens` | Erreurs inline dans le code |
| Pubspec Assist | `jeroen-meijer.pubspec-assist` | Ajouter packages facilement |
| GitLens | `eamodio.gitlens` | Git avancé dans VS Code |
| Better Comments | `aaron-bond.better-comments` | Commentaires colorés TODO/FIXME |
| Bloc Snippets | `felixangelov.bloc` | Snippets utiles (optionnel) |

Ces extensions sont aussi listées dans `.vscode/extensions.json` — VS Code les proposera automatiquement à quiconque ouvre le projet.

---

## 2. Settings VS Code pour Flutter

Créer `.vscode/settings.json` dans le projet :

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "Dart-Code.dart-code",
  "editor.tabSize": 2,
  "editor.rulers": [80],
  "dart.lineLength": 80,
  "dart.flutterSdkPath": null,
  "dart.previewFlutterUiGuides": true,
  "dart.previewFlutterUiGuidesCustomTracking": true,
  "dart.debugExternalPackageLibraries": false,
  "dart.debugSdkLibraries": false,
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.formatOnType": true,
    "editor.selectionHighlight": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": "off"
  },
  "files.exclude": {
    "**/.dart_tool": true,
    "**/.flutter-plugins": true,
    "**/.flutter-plugins-dependencies": true,
    "**/build": false
  }
}
```

---

## 3. Créer le projet Flutter

```powershell
# Dans le dossier parent où tu veux le projet
flutter create sic_mobile --org com.sic --platforms android,ios

# Renommer le dossier pour correspondre au repo
# (ou cloner le repo GitHub vide puis flutter create à l'intérieur)
cd sic_mobile
```

> Utiliser `sic_mobile` (underscore) comme nom de package Dart.
> L'organisation `com.sic` sera utilisée pour le bundle ID Android/iOS.

---

## 4. Configurer le fichier pubspec.yaml

Remplacer le contenu de `pubspec.yaml` :

```yaml
name: sic_mobile
description: SIC — Système Inter-Connexion Mobile Money
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # Réseau
  dio: ^5.4.3
  retrofit: ^4.1.0
  connectivity_plus: ^5.0.2

  # Fonctionnel (Either, Option)
  dartz: ^0.10.1

  # Cache local offline
  hive_flutter: ^1.1.0

  # Animations
  flutter_animate: ^4.5.0

  # Graphiques
  fl_chart: ^0.67.0

  # Auth biométrique
  local_auth: ^2.2.0

  # Notifications push
  firebase_core: ^2.27.0
  firebase_messaging: ^14.8.0

  # Utilitaires
  intl: ^0.19.0
  flutter_dotenv: ^5.1.0
  shared_preferences: ^2.2.3
  equatable: ^2.0.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.2
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
  retrofit_generator: ^8.1.0
  hive_generator: ^2.0.1
  mockito: ^5.4.4

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
    - assets/fonts/
    - .env
```

---

## 5. Créer la structure des dossiers

```powershell
# Depuis la racine du projet sic_mobile/
mkdir assets\images, assets\icons, assets\fonts
mkdir lib\core\constants, lib\core\errors, lib\core\network
mkdir lib\core\usecases, lib\core\utils, lib\core\widgets
mkdir lib\features\dashboard\data\datasources
mkdir lib\features\dashboard\data\models
mkdir lib\features\dashboard\data\repositories
mkdir lib\features\dashboard\domain\entities
mkdir lib\features\dashboard\domain\repositories
mkdir lib\features\dashboard\domain\usecases
mkdir lib\features\dashboard\presentation\providers
mkdir lib\features\dashboard\presentation\screens
mkdir lib\features\dashboard\presentation\widgets
mkdir lib\features\sim_management\data\datasources
mkdir lib\features\sim_management\data\models
mkdir lib\features\sim_management\data\repositories
mkdir lib\features\sim_management\domain\entities
mkdir lib\features\sim_management\domain\repositories
mkdir lib\features\sim_management\domain\usecases
mkdir lib\features\sim_management\presentation\providers
mkdir lib\features\sim_management\presentation\screens
mkdir lib\features\sim_management\presentation\widgets
mkdir test\features\dashboard
mkdir test\features\sim_management
```

---

## 6. Fichier analysis_options.yaml (linting strict)

À la racine du projet :

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    missing_required_param: error
    missing_return: error
    dead_code: warning
    unused_import: warning
    unused_local_variable: warning

linter:
  rules:
    # Style
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_fields: true
    prefer_final_locals: true
    prefer_single_quotes: true

    # Sécurité
    avoid_print: true
    avoid_dynamic_calls: true
    cancel_subscriptions: true
    close_sinks: true

    # Clean code
    avoid_unnecessary_containers: true
    use_key_in_widget_constructors: true
    sized_box_for_whitespace: true
    sort_child_properties_last: true
```

---

## 7. Fichier .editorconfig

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.dart]
max_line_length = 80

[*.md]
trim_trailing_whitespace = false
```

---

## 8. Initialiser Git

```powershell
git init
git remote add origin https://github.com/[TON_USERNAME]/sic-mobile.git

# Créer les branches
git checkout -b main
git add .
git commit -m "chore: init projet SIC Mobile Flutter"
git push -u origin main

git checkout -b develop
git push -u origin develop
```

---

## 9. Fichier .gitignore Flutter (complet)

```gitignore
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
*.iml

# Android
android/local.properties
android/.gradle
android/captures/
android/key.properties
*.jks
*.keystore

# iOS
ios/Flutter/flutter_export_environment.sh
ios/Flutter/Generated.xcconfig
ios/Pods/
ios/.symlinks/

# Environnement
.env
*.env.local
*.env.development
*.env.production

# VS Code
.vscode/launch.json

# Divers
*.log
*.tmp
.DS_Store
Thumbs.db
coverage/
```

> `.vscode/settings.json` et `.vscode/extensions.json` sont intentionnellement **inclus** dans Git pour que l'équipe partage la même config.

---

## 10. GitHub Actions — CI Flutter

Créer `.github/workflows/flutter_ci.yml` :

```yaml
name: Flutter CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test --coverage
```

> Pas de build APK en CI pour l'instant — ça ralentit inutilement. On analyse et on teste. Le build APK se fait en local ou en Phase 5.

---

## Émulateur Android recommandé

Dans Android Studio → Device Manager → Create Device :
- **Pixel 6** — API 33 (Android 13)
- RAM : 2048 MB minimum
- Activer **Hardware GLES 2.0**

Tester aussi sur un vrai appareil Android entrée de gamme pour simuler les conditions réelles des agents PDV en Afrique.
