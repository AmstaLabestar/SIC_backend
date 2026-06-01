import 'package:flutter/foundation.dart';
import 'package:sic_mobile/core/services/api_service.dart';
import 'package:sic_mobile/core/services/storage_service.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/data/models/transaction.dart';
import 'package:sic_mobile/data/models/commission_info.dart';

/// SIC Repository - Central data access layer
class SicRepository {
  static SicRepository? _instance;
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  SicRepository._internal();

  factory SicRepository() {
    _instance ??= SicRepository._internal();
    return _instance!;
  }

  // ============================================================================
  // AUTH
  // ============================================================================

  /// Login with username and password
  Future<AuthResult> login(String username, String password) async {
    final response = await _api.login(username, password);
    if (response.isSuccess) {
      // Fetch profile after login
      await fetchAndCacheProfile();
      return AuthResult.success();
    }
    return AuthResult.error(response.error ?? 'Erreur de connexion');
  }

  /// Register new agent
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _api.register(
      username: username,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName,
    );

    if (response.isSuccess) {
      return AuthResult.success();
    }
    return AuthResult.error(response.error ?? 'Erreur d\'inscription');
  }

  /// Logout
  Future<void> logout() async {
    await _api.logout();
    await _storage.clearAllSecure();
  }

  /// Check if user is logged in
  bool get isLoggedIn => _api.isAuthenticated;

  // ============================================================================
  // PROFILE
  // ============================================================================

  /// Fetch and cache agent profile
  Future<Agent?> fetchAndCacheProfile() async {
    final response = await _api.getProfile();
    if (response.isSuccess && response.data != null) {
      final agent = Agent.fromJson(response.data);
      await _storage.saveAgentProfile(agent);
      return agent;
    }
    return null;
  }

  /// Get cached profile
  Future<Agent?> getCachedProfile() async {
    return await _storage.getAgentProfile();
  }

  /// Get profile (cache first, then fetch)
  Future<Agent?> getProfile({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return await fetchAndCacheProfile();
    }

    // Check cache first
    final cached = await getCachedProfile();
    if (cached != null) {
      // Check if cache is expired
      final expired = await _storage.isSyncExpired();
      if (!expired) {
        return cached;
      }
    }

    // Fetch from API
    final fresh = await fetchAndCacheProfile();
    return fresh ?? cached;
  }

  // ============================================================================
  // PUCES
  // ============================================================================

  /// Fetch puces from API
  Future<List<Puce>> fetchPuces() async {
    final response = await _api.getPuces();
    if (response.isSuccess && response.data != null) {
      final List<dynamic> results = response.data['results'] ?? [response.data];
      final puces = results.map((json) => Puce.fromJson(json)).toList();
      await _storage.savePuces(puces);
      return puces;
    }
    return [];
  }

  /// Get cached puces
  Future<List<Puce>> getCachedPuces() async {
    return await _storage.getPuces();
  }

  /// Get puces (cache first, then fetch)
  Future<List<Puce>> getPuces({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return await fetchPuces();
    }

    final cached = await getCachedPuces();
    if (cached.isNotEmpty && !await _storage.isSyncExpired()) {
      return cached;
    }

    return await fetchPuces();
  }

  /// Add a new puce
  Future<Result> addPuce({
    required String operator,
    required String phoneNumber,
  }) async {
    final response = await _api.addPuce(
      operator: operator,
      phoneNumber: phoneNumber,
    );

    if (response.isSuccess) {
      await fetchPuces(); // Refresh cache
      return Result.success();
    }
    return Result.error(response.error ?? 'Erreur lors de l\'ajout de la puce');
  }

  /// Delete a puce
  Future<Result> deletePuce(String id) async {
    final response = await _api.deletePuce(id);
    if (response.isSuccess) {
      await fetchPuces(); // Refresh cache
      return Result.success();
    }
    return Result.error(response.error ?? 'Erreur lors de la suppression');
  }

  // ============================================================================
  // TRANSACTIONS
  // ============================================================================

  /// Fetch transactions from API
  Future<List<Transaction>> fetchTransactions({int page = 1}) async {
    final response = await _api.getTransactions(page: page);
    if (response.isSuccess && response.data != null) {
      final List<dynamic> results = response.data['results'] ?? [response.data];
      final transactions = results.map((json) => Transaction.fromJson(json)).toList();

      // Cache only first page
      if (page == 1) {
        await _storage.saveTransactions(transactions);
      }

      return transactions;
    }
    return [];
  }

  /// Get cached transactions
  Future<List<Transaction>> getCachedTransactions() async {
    return await _storage.getTransactions();
  }

  /// Get transactions (cache first, then fetch)
  Future<List<Transaction>> getTransactions({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return await fetchTransactions();
    }

    final cached = await getCachedTransactions();
    if (cached.isNotEmpty && !await _storage.isSyncExpired()) {
      return cached;
    }

    return await fetchTransactions();
  }

  /// Get transaction by ID
  Future<Transaction?> getTransaction(String id) async {
    final response = await _api.getTransaction(id);
    if (response.isSuccess && response.data != null) {
      return Transaction.fromJson(response.data);
    }
    return null;
  }

  /// Make a deposit
  Future<TransactionResult> deposit({
    required double amount,
    required String targetOperator,
    required String targetPhoneNumber,
    String? pinToken,
  }) async {
    final response = await _api.deposit(
      amount: amount,
      targetOperator: targetOperator,
      targetPhoneNumber: targetPhoneNumber,
      pinToken: pinToken,
    );

    if (response.isSuccess && response.data != null) {
      await fetchTransactions(); // Refresh cache
      await fetchPuces(); // Refresh puces as balance may have changed
      return TransactionResult.success(
        transactionId: response.data['transaction_id']?.toString() ?? '',
        status: response.data['status']?.toString() ?? 'PENDING',
      );
    }
    return TransactionResult.error(response.error ?? 'Erreur lors du dépôt');
  }

  /// Make a withdrawal
  Future<TransactionResult> withdraw({
    required double amount,
    required String targetOperator,
    required String targetPhoneNumber,
    String? pinToken,
  }) async {
    final response = await _api.withdraw(
      amount: amount,
      targetOperator: targetOperator,
      targetPhoneNumber: targetPhoneNumber,
      pinToken: pinToken,
    );

    if (response.isSuccess && response.data != null) {
      await fetchTransactions();
      await fetchPuces();
      return TransactionResult.success(
        transactionId: response.data['transaction_id']?.toString() ?? '',
        status: response.data['status']?.toString() ?? 'PENDING',
      );
    }
    return TransactionResult.error(response.error ?? 'Erreur lors du retrait');
  }

  /// Convert between puces
  Future<TransactionResult> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
    String? pinToken,
  }) async {
    final response = await _api.convert(
      amount: amount,
      sourcePuceId: sourcePuceId,
      targetPuceId: targetPuceId,
      pinToken: pinToken,
    );

    if (response.isSuccess && response.data != null) {
      await fetchTransactions();
      await fetchPuces();
      return TransactionResult.success(
        transactionId: response.data['transaction_id']?.toString() ?? '',
        status: response.data['status']?.toString() ?? 'PENDING',
      );
    }
    return TransactionResult.error(response.error ?? 'Erreur lors de la conversion');
  }

  // ============================================================================
  // COMMISSION INFO
  // ============================================================================

  /// Get commission info
  Future<CommissionInfo?> getCommissionInfo() async {
    final response = await _api.getCommissions();
    if (response.isSuccess && response.data != null) {
      return CommissionInfo.fromJson(response.data);
    }
    return null;
  }

  // ============================================================================
  // PIN
  // ============================================================================

  /// Setup PIN
  Future<Result> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async {
    final response = await _api.setupPin(password, pin, pinConfirm);
    if (response.isSuccess) {
      await _storage.setPinSetup(true);
      return Result.success();
    }
    return Result.error(response.error ?? 'Erreur lors de la configuration du PIN');
  }

  /// Verify PIN
  Future<PinVerifyResult> verifyPin(String pin) async {
    final response = await _api.verifyPin(pin);
    if (response.isSuccess && response.data != null) {
      return PinVerifyResult.success(
        pinToken: response.data['pin_token']?.toString(),
      );
    }
    return PinVerifyResult.error(response.error ?? 'Code PIN incorrect');
  }

  /// Register biometric public key for this device
  Future<Result> registerBiometric({
    required String deviceId,
    required String publicKeyBase64,
  }) async {
    final response = await _api.registerBiometric(
      deviceId: deviceId,
      publicKeyBase64: publicKeyBase64,
    );

    if (response.isSuccess) {
      return Result.success();
    }
    return Result.error(response.error ?? 'Erreur lors de l\'enregistrement biométrique');
  }

  /// Biometric login using device signature
  Future<AuthResult> biometricLogin({
    required String deviceId,
    required int timestamp,
    required String signatureBase64,
  }) async {
    final response = await _api.biometricLogin(
      deviceId: deviceId,
      timestamp: timestamp,
      signatureBase64: signatureBase64,
    );

    if (response.isSuccess) {
      await fetchAndCacheProfile();
      return AuthResult.success();
    }
    return AuthResult.error(response.error ?? 'Erreur lors de l\'authentification biométrique');
  }

  // ============================================================================
  // HEALTH CHECK
  // ============================================================================

  /// Check API health
  Future<bool> checkHealth() async {
    final response = await _api.healthCheck();
    return response.isSuccess;
  }
}

// ============================================================================
// RESULT CLASSES
// ============================================================================

class Result {
  final bool isSuccess;
  final String? error;

  Result._({required this.isSuccess, this.error});

  factory Result.success() => Result._(isSuccess: true);
  factory Result.error(String message) => Result._(isSuccess: false, error: message);
}

class AuthResult extends Result {
  AuthResult._({required super.isSuccess, super.error}) : super._();

  factory AuthResult.success() => AuthResult._(isSuccess: true);
  factory AuthResult.error(String message) => AuthResult._(isSuccess: false, error: message);
}

class TransactionResult {
  final bool isSuccess;
  final String? error;
  final String? transactionId;
  final String? status;

  TransactionResult._({
    required this.isSuccess,
    this.error,
    this.transactionId,
    this.status,
  });

  factory TransactionResult.success({
    required String transactionId,
    required String status,
  }) =>
      TransactionResult._(
        isSuccess: true,
        transactionId: transactionId,
        status: status,
      );

  factory TransactionResult.error(String message) =>
      TransactionResult._(isSuccess: false, error: message);
}

class PinVerifyResult {
  final bool isSuccess;
  final String? error;
  final String? pinToken;

  PinVerifyResult._({required this.isSuccess, this.error, this.pinToken});

  factory PinVerifyResult.success({String? pinToken}) =>
      PinVerifyResult._(isSuccess: true, pinToken: pinToken);

  factory PinVerifyResult.error(String message) =>
      PinVerifyResult._(isSuccess: false, error: message);
}