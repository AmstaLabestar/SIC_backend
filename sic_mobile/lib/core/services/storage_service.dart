import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sic_mobile/config/constants.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/data/models/puce.dart';
import 'package:sic_mobile/data/models/transaction.dart';

/// Storage Service for SIC Mobile
/// Handles secure storage for tokens and general storage for app data
class StorageService {
  static StorageService? _instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StorageService._internal();

  factory StorageService() {
    _instance ??= StorageService._internal();
    return _instance!;
  }

  // ============================================================================
  // SECURE STORAGE (Tokens, sensitive data)
  // ============================================================================

  Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  Future<void> clearAllSecure() async {
    await _secureStorage.deleteAll();
  }

  // ============================================================================
  // SHARED PREFERENCES (App data, settings)
  // ============================================================================

  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // Boolean
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await _prefs;
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  // String
  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  // Int
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final prefs = await _prefs;
    return prefs.getInt(key) ?? defaultValue;
  }

  Future<void> setInt(String key, int value) async {
    final prefs = await _prefs;
    await prefs.setInt(key, value);
  }

  // Double
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final prefs = await _prefs;
    return prefs.getDouble(key) ?? defaultValue;
  }

  Future<void> setDouble(String key, double value) async {
    final prefs = await _prefs;
    await prefs.setDouble(key, value);
  }

  // JSON (Complex objects)
  Future<void> saveJson(String key, Map<String, dynamic> data) async {
    await setString(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> readJson(String key) async {
    final data = await getString(key);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('Error decoding JSON for $key: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final data = await getString(key);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) print('Error decoding JSON list for $key: $e');
      return [];
    }
  }

  // Remove
  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  // Clear all
  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // ============================================================================
  // AGENT PROFILE
  // ============================================================================

  Future<void> saveAgentProfile(Agent agent) async {
    await saveJson(StorageKeys.agentProfile, agent.toJson());
  }

  Future<Agent?> getAgentProfile() async {
    final data = await readJson(StorageKeys.agentProfile);
    if (data == null) return null;
    try {
      return Agent.fromJson(data);
    } catch (e) {
      if (kDebugMode) print('Error parsing agent profile: $e');
      return null;
    }
  }

  // ============================================================================
  // PUCES
  // ============================================================================

  Future<void> savePuces(List<Puce> puces) async {
    final data = puces.map((p) => p.toJson()).toList();
    await setString(StorageKeys.puces, jsonEncode(data));
  }

  Future<List<Puce>> getPuces() async {
    final data = await readJsonList(StorageKeys.puces);
    return data.map((json) => Puce.fromJson(json)).toList();
  }

  // ============================================================================
  // TRANSACTIONS
  // ============================================================================

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final data = transactions.map((t) => t.toJson()).toList();
    await setString(StorageKeys.transactions, jsonEncode(data));
  }

  Future<List<Transaction>> getTransactions() async {
    final data = await readJsonList(StorageKeys.transactions);
    return data.map((json) => Transaction.fromJson(json)).toList();
  }

  // ============================================================================
  // APP SETTINGS
  // ============================================================================

  bool get isDarkMode {
    getBool(StorageKeys.isDarkMode).then((value) => value);
    return false; // Default to light mode
  }

  Future<void> setDarkMode(bool value) async {
    await setBool(StorageKeys.isDarkMode, value);
  }

  bool get isBiometricsEnabled {
    getBool(StorageKeys.biometricsEnabled).then((value) => value);
    return false;
  }

  Future<void> setBiometricsEnabled(bool value) async {
    await setBool(StorageKeys.biometricsEnabled, value);
  }

  bool get isPinSetup {
    getBool(StorageKeys.pinSetup).then((value) => value);
    return false;
  }

  Future<void> setPinSetup(bool value) async {
    await setBool(StorageKeys.pinSetup, value);
  }

  // ============================================================================
  // SYNC TIMESTAMP
  // ============================================================================

  Future<DateTime?> getLastSync() async {
    final timestamp = await getString(StorageKeys.lastSync);
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  Future<void> setLastSync(DateTime dateTime) async {
    await setString(StorageKeys.lastSync, dateTime.toIso8601String());
  }

  Future<bool> isSyncExpired() async {
    final lastSync = await getLastSync();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > AppConstants.cacheDuration;
  }
}