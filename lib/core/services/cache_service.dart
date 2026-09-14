import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';
import '../models/hazard_data.dart';
import '../models/risk_state.dart';

class CacheService {
  static const String _keyWeather = 'aarakshak_cached_weather';
  static const String _keyHazards = 'aarakshak_cached_hazards';
  static const String _keyRiskState = 'aarakshak_cached_risk';

  Future<void> saveWeather(WeatherData weather) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWeather, jsonEncode(weather.toJson()));
    } catch (_) {}
  }

  Future<WeatherData?> getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyWeather);
      if (str != null) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return WeatherData.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveHazards(List<HazardData> hazards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = hazards.map((h) => h.toJson()).toList();
      await prefs.setString(_keyHazards, jsonEncode(list));
    } catch (_) {}
  }

  Future<List<HazardData>> getCachedHazards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyHazards);
      if (str != null) {
        final list = jsonDecode(str) as List;
        return list.map((e) => HazardData.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveRiskState(ContextRiskState riskState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRiskState, jsonEncode(riskState.toJson()));
    } catch (_) {}
  }
}
