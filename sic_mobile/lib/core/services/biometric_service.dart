import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Platform-specific secure storage options
final _androidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);

final _iOptions = IOSOptions(
  accessibility: IOSAccessibility.first_unlock,
);

/// Biometric Service for SIC Mobile
/// Handles fingerprint authentication and device registration
class BiometricService {
  static BiometricService? _instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  BiometricService._internal();

  factory BiometricService() {
    _instance ??= BiometricService._internal();
    return _instance!;
  }

  // ============================================================================
  // BIOMETRIC AVAILABILITY
  // ============================================================================

  /// Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      if (kDebugMode) print('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      if (kDebugMode) print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if fingerprint is available
  Future<bool> hasFingerprint() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint) ||
           biometrics.contains(BiometricType.strong);
  }

  /// Check if face recognition is available
  Future<bool> hasFaceRecognition() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Authenticate with biometrics
  Future<BiometricResult> authenticate({
    String reason = 'Authentifiez-vous pour accéder à SIC Mobile',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return BiometricResult.error('Biométrie non disponible sur cet appareil');
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        return BiometricResult.success();
      } else {
        return BiometricResult.error('Authentification annulée');
      }
    } catch (e) {
      if (kDebugMode) print('Biometric authentication error: $e');
      return BiometricResult.error('Erreur d\'authentification biométrique');
    }
  }

  // ============================================================================
  // DEVICE REGISTRATION
  // ============================================================================

  /// Generate a unique device ID
  String generateDeviceId() {
    return const Uuid().v4();
  }

  /// Generate an Ed25519 key pair for device authentication.
  /// Stores the private key securely and returns the public key (base64) + device_id.
  Future<DeviceKeyPair> generateKeyPair() async {
    final deviceId = generateDeviceId();
    final algorithm = Ed25519();

    // Generate key pair
    final keyPair = await algorithm.newKeyPair();

    // Extract key material
    final keyPairData = await keyPair.extract();
    final privateKeyBytes = keyPairData.bytes;

    // Extract public key
    final publicKey = await algorithm.extractPublicKey(keyPair);
    final publicKeyBytes = publicKey.bytes;

    // Store private key securely (base64) using platform keystore/keychain options
    final storage = const FlutterSecureStorage();
    await storage.write(
      key: 'biometric_private_$deviceId',
      value: base64.encode(privateKeyBytes),
      aOptions: _androidOptions,
      iOptions: _iOptions,
    );

    return DeviceKeyPair(
      deviceId: deviceId,
      publicKey: base64.encode(publicKeyBytes),
      privateKey: base64.encode(privateKeyBytes),
    );
  }

  /// Sign a challenge for biometric login using stored private key (Ed25519).
  Future<String> signChallenge(String deviceId, int timestamp) async {
    final storage = const FlutterSecureStorage();
    final key = await storage.read(
      key: 'biometric_private_$deviceId',
      aOptions: _androidOptions,
      iOptions: _iOptions,
    );
    if (key == null) return '';

    final privateKeyBytes = base64.decode(key);
    final algorithm = Ed25519();

    final message = utf8.encode('$deviceId:$timestamp');

    // Recreate key pair from private key bytes
    final keyPair = SimpleKeyPairData(privateKeyBytes, type: KeyPairType.ed25519);
    final signature = await algorithm.sign(
      message,
      keyPair: keyPair,
    );

    return base64.encode(signature.bytes);
  }

  /// Verify a signature locally (debugging) - not used in production
  Future<bool> verifySignature(
    String signatureBase64,
    String deviceId,
    int timestamp,
    String publicKeyBase64,
  ) async {
    try {
      final algorithm = Ed25519();
      final pubBytes = base64.decode(publicKeyBase64);
      final sigBytes = base64.decode(signatureBase64);
      final message = utf8.encode('$deviceId:$timestamp');

      final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      // Use the algorithm to verify
      await algorithm.verify(
        message,
        signature: Signature(sigBytes, publicKey: publicKey),
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('Local verify failed: $e');
      return false;
    }
  }

  /// Check if signature is expired (5 minute window)
  bool isSignatureExpired(int timestamp, {int windowSeconds = 300}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - timestamp).abs() > windowSeconds;
  }

  // ============================================================================
  // CANCEL AUTHENTICATION
  // ============================================================================

  /// Cancel any ongoing authentication
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      if (kDebugMode) print('Error cancelling authentication: $e');
    }
  }
}

/// Result of biometric authentication
class BiometricResult {
  final bool isSuccess;
  final String? error;
  final String? message;

  BiometricResult._({
    required this.isSuccess,
    this.error,
    this.message,
  });

  factory BiometricResult.success({String? message}) {
    return BiometricResult._(isSuccess: true, message: message);
  }

  factory BiometricResult.error(String error) {
    return BiometricResult._(isSuccess: false, error: error);
  }
}

/// Key pair for device authentication
class DeviceKeyPair {
  final String deviceId;
  final String publicKey;
  final String privateKey;

  DeviceKeyPair({
    required this.deviceId,
    required this.publicKey,
    required this.privateKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'public_key': publicKey,
    };
  }

  @override
  String toString() {
    return 'DeviceKeyPair(deviceId: $deviceId)';
  }
}