# SIC Mobile Security Overview

## ✅ Security posture

- **Biometric authentication** is now based on **Ed25519 digital signatures**.
- The mobile app generates a unique **device_id** and an Ed25519 key pair on registration.
- The **private key is stored securely** using `flutter_secure_storage` with platform-specific options:
  - `AndroidOptions(encryptedSharedPreferences: true)`
  - `IOSOptions(accessibility: IOSAccessibility.first_unlock)`
- The **public key is sent to the backend** and registered for the agent's biometric device.
- On biometric login, the app performs local biometric verification and then signs the challenge `device_id:timestamp` with the stored private key.
- The backend verifies the signature using the stored public key and grants JWT tokens only for valid signed requests.
- The app also uses **JWT access + refresh tokens**, with secure token storage.
- **PIN-protected actions** pass a signed `pin_token` from the backend for sensitive transactions.

## 🔐 What changed

- Replaced legacy HMAC/MD5 biometric fallback with asymmetric cryptography.
- Added secure private key storage options for Android/iOS.
- Added client APIs for biometric device registration and login.
- Added a strict backend policy to disable legacy biometric fallback unless `ALLOW_LEGACY_BIOMETRIC=True`.

## 🧪 Local development guidance

- In production, keep `ALLOW_LEGACY_BIOMETRIC=False`.
- For local development or compatibility testing, enable legacy biometric fallback explicitly with:
  ```powershell
  $env:ALLOW_LEGACY_BIOMETRIC='True'
  python manage.py runserver
  ```
- Prefer using the new Ed25519 biometric flow for all new devices.

## ✅ Remaining checks

- [ ] Verify biometric registration and login end-to-end on a physical device.
- [ ] Validate that `flutter_secure_storage` works correctly on both Android and iOS with the selected options.
- [ ] Confirm `pin_token` flow for deposit/withdraw/convert endpoints.
- [ ] Audit backend `api/views.py` to ensure legacy biometric fallback is disabled in production.
- [ ] Remove `ALLOW_LEGACY_BIOMETRIC=True` from production environment variables once the migration is complete.

## 📌 Best practice

- Do not store private keys in plain text or shared preferences.
- Do not allow legacy cryptographic fallbacks in production.
- Keep biometric challenge timestamps within a 5-minute window.
- Use physical devices for biometric testing rather than emulators when possible.
