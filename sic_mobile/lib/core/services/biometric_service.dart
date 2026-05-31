import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

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

  /// Generate a key pair for device authentication (simplified)
  /// In production, use flutter_secure_storage with RSA keys
  Future<DeviceKeyPair> generateKeyPair() async {
    // Generate a simple key pair for HMAC signature
    // In production, use proper RSA/ECDH key exchange
    final deviceId = generateDeviceId();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final secret = '$deviceId:$timestamp:device_key';

    // Generate a signature
    final signature = md5.convert(utf8.encode(secret)).toString();

    return DeviceKeyPair(
      deviceId: deviceId,
      publicKey: signature,
      privateKey: secret,
    );
  }

  /// Sign a challenge for biometric login
  String signChallenge(String deviceId, int timestamp, String publicKey) {
    final data = '$deviceId:$timestamp:$publicKey';
    return md5.convert(utf8.encode(data)).toString();
  }

  /// Verify a signature
  bool verifySignature(
    String signature,
    String deviceId,
    int timestamp,
    String publicKey,
  ) {
    final expected = signChallenge(deviceId, timestamp, publicKey);
    return signature == expected;
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