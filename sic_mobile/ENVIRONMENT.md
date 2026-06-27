# Environnement de développement — SIC Mobile

> Mettre en place l'environnement pour développer et lancer l'app. Le projet existe déjà ;
> ce guide ne le recrée pas, il configure une machine de dev.

---

## 1. Pré-requis

```bash
flutter --version     # Flutter 3.x (Dart 3.x)
flutter doctor        # corriger les warnings bloquants (toolchain Android)
adb --version         # Android Platform Tools (pour device réel)
```

Recommandé : VS Code (extensions **Dart** + **Flutter**) ou Android Studio. Cible de
test idéale : un **appareil Android réel d'entrée de gamme** (les agents PDV utilisent ce
type de matériel) ; à défaut, un émulateur Pixel API 33+.

---

## 2. Installation

```bash
cd sic_mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Riverpod / Retrofit / Hive
```

> Re-lancer `build_runner` après toute modification d'un fichier généré (providers
> Riverpod annotés, clients Retrofit, adapters Hive).

---

## 3. Configuration `.env` (non commité)

L'app lit sa config via `flutter_dotenv`. Créer `sic_mobile/.env` :

```env
API_BASE_URL=http://localhost:8000/api
WS_URL=ws://localhost:8000/ws/notifications/
# Optionnel — monitoring d'erreurs (sinon Sentry reste inactif) :
SENTRY_DSN=
```

`.env` est dans `assets:` (pubspec) et **ignoré par git**. Ne jamais y mettre de secret
de production.

---

## 4. Lancer contre le backend local

Le backend tourne en Docker (voir [../README.md](../README.md)). Pour qu'un **device réel**
branché en USB atteigne le backend de la machine :

```bash
adb devices                        # vérifier que le device est listé
adb reverse tcp:8000 tcp:8000      # device:8000 → machine:8000 (REST + WebSocket)
flutter run                        # debug avec hot reload
```

> Avec `adb reverse`, `localhost:8000` côté téléphone pointe vers le backend de la
> machine — pas besoin d'IP LAN. Émulateur : utiliser `10.0.2.2:8000` à la place.

Codes OTP en dev : ils s'affichent dans les logs backend (`docker compose logs -f web`).

---

## 5. Qualité (avant chaque commit)

```bash
flutter analyze        # doit être PROPRE (zéro issue)
flutter test           # tests unitaires + widget (+ E2E pilote)
flutter build apk       # vérifier que le build passe
```

Règle de lot : `analyze` propre + tests verts + build OK, puis commit (cf.
[CONVENTIONS.md](CONVENTIONS.md)).

---

## 6. Build APK / install device

```bash
flutter build apk                          # build/app/outputs/flutter-apk/app-release.apk (ou debug)
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Profiler la fluidité sur device (optimisations perf) :
flutter run --profile                      # + overlay performance
```

Génération des icônes de lancement (déjà configurée sur `assets/icons/app_icon.jpeg`) :

```bash
dart run flutter_launcher_icons
```

> ⚠️ Avant une vraie publication : `applicationId` réel (pas le placeholder), keystore de
> signature, `flutter build apk --release`. Voir [ROADMAP.md](ROADMAP.md) §8.
