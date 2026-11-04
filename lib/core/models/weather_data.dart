/// Weather model representing parameters from Open-Meteo & IMD feeds
class WeatherData {
  final double temperature;
  final double humidity;
  final double precipitation;
  final double rain;
  final double windSpeed;
  final int weatherCode;
  final DateTime timestamp;
  final bool isCached;
  final String provider;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.rain,
    required this.windSpeed,
    required this.weatherCode,
    required this.timestamp,
    this.isCached = false,
    this.provider = 'Open-Meteo API',
  });

  /// Map WMO Weather Interpretation Code to human-readable description
  static String weatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Cloudy';
    if (code >= 51 && code <= 67) return 'Rain';
    if (code >= 80 && code <= 82) return 'Heavy Rain';
    if (code >= 95) return 'Thunderstorm';
    return 'Unknown';
  }

  /// Get corresponding emoji for weather code
  String get weatherEmoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode >= 1 && weatherCode <= 3) return '⛅';
    if (weatherCode >= 51 && weatherCode <= 67) return '🌧️';
    if (weatherCode >= 80 && weatherCode <= 82) return '🌧️';
    if (weatherCode >= 95) return '🌩️';
    return '🌡️';
  }

  /// Human-readable weather condition text
  String get conditionText => weatherDescription(weatherCode);

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'precipitation': precipitation,
      'rain': rain,
      'windSpeed': windSpeed,
      'weatherCode': weatherCode,
      'timestamp': timestamp.toIso8601String(),
      'isCached': isCached,
      'provider': provider,
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      precipitation: (json['precipitation'] as num).toDouble(),
      rain: (json['rain'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      weatherCode: (json['weatherCode'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isCached: json['isCached'] as bool? ?? true,
      provider: json['provider'] as String? ?? 'Cached Local Telemetry',
    );
  }

  factory WeatherData.fallbackDemo() {
    return WeatherData(
      temperature: 27.0,
      humidity: 82.0,
      precipitation: 8.2,
      rain: 8.2,
      windSpeed: 24.0,
      weatherCode: 81,
      timestamp: DateTime.now(),
      isCached: true,
      provider: 'Offline Weather Telemetry',
    );
  }
}
