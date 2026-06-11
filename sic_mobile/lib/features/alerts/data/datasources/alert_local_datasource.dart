import 'package:hive_flutter/hive_flutter.dart';

import '../models/alert_config_model.dart';

class AlertLocalDatasource {
  const AlertLocalDatasource();

  static const boxName = 'alert_configs';

  static final Map<String, String> _defaultOperators = {
    'OM': 'Orange Money',
    'MOOV': 'Moov Money',
    'TELECEL': 'Telecel Money',
  };

  Future<List<AlertConfigModel>> getAlertConfigs() async {
    final box = await _openBox();

    if (box.isEmpty) {
      await _seedDefaults(box);
    }

    return _defaultOperators.keys.map((operatorCode) {
      final rawConfig = box.get(operatorCode);
      if (rawConfig == null) {
        return _defaultConfig(operatorCode);
      }

      return AlertConfigModel.fromJson(rawConfig);
    }).toList();
  }

  Future<AlertConfigModel> saveAlertConfig(AlertConfigModel config) async {
    final box = await _openBox();
    final updatedConfig = AlertConfigModel(
      operatorCode: config.operatorCode,
      operatorName: config.operatorName,
      isEnabled: config.isEnabled,
      threshold: config.threshold,
      lastUpdated: DateTime.now(),
    );

    await box.put(updatedConfig.operatorCode, updatedConfig.toJson());
    return updatedConfig;
  }

  Future<Box<Map<dynamic, dynamic>>> _openBox() {
    return Hive.openBox<Map<dynamic, dynamic>>(boxName);
  }

  Future<void> _seedDefaults(Box<Map<dynamic, dynamic>> box) async {
    for (final operatorCode in _defaultOperators.keys) {
      final config = _defaultConfig(operatorCode);
      await box.put(operatorCode, config.toJson());
    }
  }

  AlertConfigModel _defaultConfig(String operatorCode) {
    return AlertConfigModel(
      operatorCode: operatorCode,
      operatorName: _defaultOperators[operatorCode] ?? operatorCode,
      isEnabled: true,
      threshold: 50000,
      lastUpdated: DateTime.now(),
    );
  }
}
