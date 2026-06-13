import 'package:biometric_signature/biometric_signature.dart';

/// Abstraction du capteur biometrique (prompt + cle materielle + signature).
///
/// Isolee derriere une interface pour que la couche repository reste testable
/// (les appels natifs ne sont pas unit-testables).
abstract class BiometricAuthenticator {
  /// Materiel biometrique present ET au moins une empreinte/visage enrole.
  Future<bool> isAvailable();

  /// Une paire de cles SIC existe deja sur cet appareil (= biometrie activee).
  Future<bool> hasKeys();

  /// Genere une paire de cles protegee par biometrie et retourne la cle
  /// publique au format PEM (compatible verification RSA backend), ou `null`
  /// si l'utilisateur annule / echec.
  Future<String?> createKeys();

  /// Signe [payload] avec la cle privee (deverrouillee par empreinte) et
  /// retourne la signature base64, ou `null` si annule / echec.
  Future<String?> sign(String payload);

  /// Supprime la paire de cles SIC (desactivation de la biometrie).
  Future<void> deleteKeys();

  /// Simple invite biometrique sans cryptographie (verrou app, palier P2).
  Future<bool> prompt(String reason);
}

/// Implementation native via le plugin `biometric_signature`.
///
/// RSA-2048 (le backend verifie PKCS1v15/SHA256 sur le chemin PEM ; ECDSA
/// echouerait sur sa branche generique). La cle est invalidee si de nouvelles
/// empreintes sont enrolees (anti-compromission).
class BiometricService implements BiometricAuthenticator {
  BiometricService([BiometricSignature? signer])
      : _bio = signer ?? BiometricSignature();

  final BiometricSignature _bio;

  static const _alias = 'sic_auth';

  @override
  Future<bool> isAvailable() async {
    try {
      final a = await _bio.biometricAuthAvailable();
      return (a.canAuthenticate ?? false) && (a.hasEnrolledBiometrics ?? false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasKeys() async {
    try {
      return await _bio.biometricKeyExists(keyAlias: _alias);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> createKeys() async {
    final result = await _bio.createKeys(
      keyAlias: _alias,
      keyFormat: KeyFormat.pem,
      config: CreateKeysConfig(
        signatureType: SignatureType.rsa,
        setInvalidatedByBiometricEnrollment: true,
      ),
      promptMessage: 'Activer la connexion biometrique',
    );
    return result.publicKey;
  }

  @override
  Future<String?> sign(String payload) async {
    final result = await _bio.createSignature(
      payload: payload,
      keyAlias: _alias,
      signatureFormat: SignatureFormat.base64,
      promptMessage: 'Confirmez avec votre empreinte',
    );
    return result.signature;
  }

  @override
  Future<void> deleteKeys() async {
    try {
      await _bio.deleteKeys(keyAlias: _alias);
    } catch (_) {
      // Suppression best-effort : l'etat applicatif sera quand meme nettoye.
    }
  }

  @override
  Future<bool> prompt(String reason) async {
    try {
      final result = await _bio.simplePrompt(promptMessage: reason);
      return result.success ?? false;
    } catch (_) {
      return false;
    }
  }
}
