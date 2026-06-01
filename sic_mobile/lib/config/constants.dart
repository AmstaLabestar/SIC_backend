import 'package:flutter/material.dart';

/// API Configuration for SIC Mobile
class ApiConstants {
  // Base URL - Change this to your production URL
  static const String baseUrl = 'http://localhost:8000/api';

  // Auth Endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String refresh = '/auth/refresh/';
  static const String verify = '/auth/verify/';
  static const String logout = '/auth/logout/';
  static const String profile = '/auth/profile/';

  // PIN Endpoints
  static const String pinSetup = '/auth/pin/setup/';
  static const String pinVerify = '/auth/pin/verify/';

  // Biometric Endpoints
  static const String biometricLogin = '/auth/biometric/login/';
  static const String biometricRegister = '/auth/biometric/register/';
  static const String biometricDevices = '/auth/biometric/devices/';

  // Transaction Endpoints
  static const String deposit = '/transactions/deposit/';
  static const String withdraw = '/transactions/withdraw/';
  static const String conversion = '/transactions/conversion/';
  static const String transactions = '/transactions/';
  static const String transactionWebhook = '/transactions/webhook/';

  // Puces Endpoints
  static const String puces = '/puces/';

  // Info Endpoints
  static const String commissions = '/commissions/';
  static const String health = '/health/';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

/// App Constants
class AppConstants {
  static const String appName = 'SIC Mobile';
  static const String appVersion = '1.0.0';

  // PIN Settings
  static const int minPinLength = 4;
  static const int maxPinLength = 6;

  // Transaction Limits
  static const int minTransactionAmount = 100;
  static const int maxTransactionAmount = 5000000;

  // Session Timeout (5 minutes)
  static const Duration sessionTimeout = Duration(minutes: 5);

  // Cache Duration
  static const Duration cacheDuration = Duration(hours: 24);

  // Operators
  static const List<String> operators = ['ORANGE', 'MOOV', 'TELECEL', 'CORIS'];

  // Transaction Types
  static const List<String> transactionTypes = ['DEPOT', 'RETRAIT', 'TRANSFERT', 'SWAP'];
}

/// Storage Keys
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userProfile = 'user_profile';
  static const String agentProfile = 'agent_profile';
  static const String puces = 'puces';
  static const String transactions = 'transactions';
  static const String isDarkMode = 'is_dark_mode';
  static const String biometricsEnabled = 'biometrics_enabled';
  static const String pinSetup = 'pin_setup';
  static const String biometricDeviceId = 'biometric_device_id';
  static const String lastSync = 'last_sync';
  static const String pendingActions = 'pending_actions';
}