# SIC Mobile — Système Inter-Connexion

> Application mobile Flutter pour agents PDV — interconnexion Mobile Money multi-opérateurs.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean-green)](docs/ARCHITECTURE.md)
[![License](https://img.shields.io/badge/License-Proprietary-red)](LICENSE)

---

## Vue d'ensemble

SIC Mobile permet aux agents PDV de gérer tous leurs portefeuilles Mobile Money (Orange Money, Moov Money, Telecel, MTN…) depuis une seule interface. L'app détecte automatiquement les insuffisances de solde et guide l'agent dans des compensations inter-réseaux étape par étape.

**Acteurs :** Agents PDV · Clients finaux · Plateforme SIC (commission automatique)

---

## Documentation

| Fichier | Contenu |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Clean Architecture, structure des dossiers, principes SOLID |
| [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md) | Installation, outils, configuration VS Code, Windows |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | Conventions Git, nommage, style de code Dart |
| [docs/PHASE2.md](docs/PHASE2.md) | Roadmap Phase 2 — Dashboard & gestion des puces |
| [docs/PROMPTS_PHASE2.md](docs/PROMPTS_PHASE2.md) | Prompts IA étape par étape pour coder la Phase 2 |
| [docs/BACKEND_CONTRACT.md](docs/BACKEND_CONTRACT.md) | Contrat API attendu du backend Django (endpoints, modèles) |

---

## Phases du projet

```
Phase 1 — Auth & Onboarding        [ À venir ]
Phase 2 — Dashboard & Puces        [ EN COURS ]
Phase 3 — Moteur Opérations        [ À venir ]
Phase 4 — Historique & Reporting   [ À venir ]
Phase 5 — Tests & Déploiement      [ À venir ]
```

---

## Stack technique

| Couche | Technologie | Rôle |
|---|---|---|
| UI | Flutter 3.x (Dart) | App iOS + Android |
| État | Riverpod 2.x | State management réactif |
| Navigation | go_router | Navigation déclarative + guards |
| Réseau | Dio + Retrofit | Appels API REST |
| Cache local | Hive / Isar | Offline — soldes, historique |
| Animations | flutter_animate | Micro-interactions, transitions |
| Graphiques | fl_chart | Dashboard bénéfices |
| Auth locale | local_auth | Biométrie (empreinte / Face ID) |
| Notifications | firebase_messaging | Push FCM |
| PDF | pdf + printing | Reçus transactions |
| Qualité | flutter_lints + custom analysis | Linting strict |

---

## Démarrage rapide

> Pré-requis : Flutter 3.x installé, VS Code, Android Studio (émulateur)
> Voir [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md) pour la configuration complète.

```bash
# 1. Cloner le repo
git clone https://github.com/[org]/sic-mobile.git
cd sic-mobile

# 2. Installer les dépendances
flutter pub get

# 3. Générer les fichiers auto-générés (Riverpod, Retrofit, Hive)
dart run build_runner build --delete-conflicting-outputs

# 4. Lancer sur émulateur
flutter run

# 5. Lancer les tests
flutter test
```

---

## Branches

| Branche | Rôle |
|---|---|
| `main` | Production — protégée, merge via PR uniquement |
| `develop` | Intégration — base de travail |
| `feature/phase2-*` | Fonctionnalités Phase 2 |
| `fix/*` | Corrections de bugs |

---

## Variables d'environnement

Créer un fichier `.env` à la racine (non commité) :

```env
API_BASE_URL=http://10.0.2.2:8000/api/v1
API_TIMEOUT=30000
ENV=development
```

> `.env` est dans `.gitignore`. Ne jamais commiter les clés API.

---

## Contacts

| Rôle | Responsabilité |
|---|---|
| Dev Frontend (toi) | Flutter, UI/UX, intégration API |
| Dev Backend | Django, API REST, base de données |
| Chef de Projet | Validation, livraisons client |
