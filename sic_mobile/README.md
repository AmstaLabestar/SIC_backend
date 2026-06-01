# SIC Mobile - Application Flutter

Application mobile pour agents SIC - Plateforme fintech de transactions mobile money.

## 🚀 Fonctionnalités

### Authentification
- ✅ Connexion avec username/password (JWT)
- ✅ Inscription avec validation
- ✅ Code PIN (4-6 chiffres)
- ✅ Authentification biométrique (empreinte digitale)
- ✅ Déconnexion sécurisée

### Dashboard
- ✅ Solde total des puces
- ✅ Liste des puces avec solde individuel
- ✅ Boutons d'action rapide
- ✅ Transactions récentes
- ✅ Pull-to-refresh

### Transactions
- ✅ Dépôt vers Mobile Money
- ✅ Retrait depuis Mobile Money
- ✅ Conversion entre puces
- ✅ Historique avec filtres
- ✅ Détail des transactions
- ✅ Statuts en temps réel

### Gestion des Puces
- ✅ Liste des puces SIM
- ✅ Ajout de puce
- ✅ Solde par puce
- ✅ Opérateurs supportés (Orange, Moov, Togocel, Coris)

### Profil & Sécurité
- ✅ Informations du compte
- ✅ Vérification KYC
- ✅ Configuration PIN
- ✅ Empreinte digitale
- ✅ Appareils enregistrés
- ✅ Paramètres de sécurité

## 🛠️ Installation

### Prérequis
- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / Xcode
- PostgreSQL (backend)
- Redis (pour Celery)

### Installation des dépendances

```bash
cd sic_mobile
flutter pub get
```

### Lancer l'application

```bash
# Mode développement
flutter run

# Mode debug
flutter run --debug

# Release
flutter run --release
```

### Configuration

1. Modifier `lib/config/constants.dart` pour configurer l'URL de l'API:
```dart
static const String baseUrl = 'http://votre-serveur:8000/api';
```

2. Configurer le backend Django dans le dossier parent:
```bash
cd ..
python manage.py runserver
```

## 📱 Captures d'écran

*(À ajouter)*

## 🏗️ Architecture

```
sic_mobile/
├── lib/
│   ├── config/          # Configuration (theme, routes, constants)
│   ├── core/            # Services core (API, storage, biometric)
│   │   ├── services/
│   │   └── utils/
│   ├── data/            # Modèles et repositories
│   │   ├── models/
│   │   ├── providers/
│   │   └── repositories/
│   ├── features/        # Fonctionnalités par module
│   │   ├── auth/
│   │   ├── home/
│   │   ├── transactions/
│   │   ├── puces/
│   │   └── profile/
│   └── shared/         # Widgets réutilisables
│       └── widgets/
├── assets/             # Images, icônes, animations
└── pubspec.yaml       # Dépendances
```

## 🎨 Design System

### Couleurs (Indigo/Violet)
- Primary: `#6366F1` (Indigo)
- Secondary: `#8B5CF6` (Violet)
- Success: `#10B981` (Emerald)
- Warning: `#F59E0B` (Amber)
- Error: `#EF4444` (Red)

### Typographie
- Headlines: Outfit Bold
- Body: Inter Regular

## 🔗 Backend API

L'application se connecte au backend Django REST Framework:

| Endpoint | Description |
|----------|-------------|
| `/api/auth/login/` | Connexion JWT |
| `/api/auth/register/` | Inscription |
| `/api/auth/pin/setup/` | Configuration PIN |
| `/api/auth/biometric/login/` | Login biométrique |
| `/api/transactions/deposit/` | Effectuer un dépôt |
| `/api/transactions/withdraw/` | Effectuer un retrait |
| `/api/transactions/` | Liste des transactions |
| `/api/puces/` | Gestion des puces |

## 📦 Dépendances principales

- **flutter_riverpod** - Gestion d'état
- **go_router** - Navigation
- **dio** - Client HTTP
- **flutter_secure_storage** - Stockage sécurisé
- **local_auth** - Authentification biométrique
- **google_fonts** - Typographie
- **intl** - Formatage dates/nombres

## 🔒 Sécurité

- Tokens JWT avec refresh automatique
- Stockage sécurisé des credentials
- PIN requis pour transactions sensibles
- Biométrie basée sur signatures Ed25519
- Clé privée stockée dans le keystore/keychain natif via `flutter_secure_storage`
- Validation côté client et serveur
- Legacy biometric fallback disabled by default in production

## 📄 Licence

Propriétaire - SIC Fintech

## 👨‍💻 Auteur

Abdouldav-cyber
