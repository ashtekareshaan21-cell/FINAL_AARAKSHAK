import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;
  final bool isMockedOrFallback;
  // Phase 1 fix: an explicit manual pick (preset landmark or custom
  // lat/lng typed by the user) is NOT live GPS, but it IS a confirmed
  // location — the user chose those exact coordinates. It must not
  // be lumped in with the unconfirmed Pune placeholder fallback.
  // isMockedOrFallback stays true for manual picks so the UI keeps
  // labelling them MANUAL instead of STREAMING LIVE.
  final bool isManualConfirmed;
  final String label;
  final String address;
  final bool isLiveTracking;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 10.0,
    this.speed = 0.0,
    this.heading = 0.0,
    required this.timestamp,
    this.isMockedOrFallback = false,
    this.isManualConfirmed = false,
    this.label = 'GPS Location',
    this.address = 'Fetching street address...',
    this.isLiveTracking = false,
  });

  // Usable for risk calculation and SOS: live GPS, or an explicit
  // manual pick. Only the unconfirmed placeholder fallback is excluded.
  bool get isConfirmedForUse => !isMockedOrFallback || isManualConfirmed;

  factory LocationData.defaultFallback() {
    // Phase 0 safety: this is explicitly NOT a confirmed location.
    // Coordinates are a placeholder only; isMockedOrFallback stays true
    // so Home SOS and risk calculation block until real GPS or an
    // explicit manual location replaces it.
    return LocationData(
      latitude: 18.5204,
      longitude: 73.8567,
      accuracy: 0.0,
      timestamp: DateTime.now(),
      isMockedOrFallback: true,
      label: 'Location not confirmed',
      address: 'GPS unavailable — location not confirmed',
      isLiveTracking: false,
    );
  }

  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    bool? isMockedOrFallback,
    bool? isManualConfirmed,
    String? label,
    String? address,
    bool? isLiveTracking,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      isMockedOrFallback: isMockedOrFallback ?? this.isMockedOrFallback,
      isManualConfirmed: isManualConfirmed ?? this.isManualConfirmed,
      label: label ?? this.label,
      address: address ?? this.address,
      isLiveTracking: isLiveTracking ?? this.isLiveTracking,
    );
  }
}

class LocationService {
  final _locationController = StreamController<LocationData>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  LocationData _currentLocation = LocationData.defaultFallback();

  LocationData get currentLocation => _currentLocation;
  Stream<LocationData> get locationStream => _locationController.stream;

  /// Fetches single position fix and starts background continuous stream
  Future<LocationData> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _currentLocation = LocationData.defaultFallback();
        return _currentLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _currentLocation = LocationData.defaultFallback();
          return _currentLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _currentLocation = LocationData.defaultFallback();
        return _currentLocation;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      _currentLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        timestamp: DateTime.now(),
        isMockedOrFallback: false,
        label: 'Live Device GPS',
        isLiveTracking: true,
      );

      _locationController.add(_currentLocation);
      startLiveTrackingStream();
      _resolveAddress(_currentLocation.latitude, _currentLocation.longitude);

      return _currentLocation;
    } catch (_) {
      _currentLocation = LocationData.defaultFallback();
      return _currentLocation;
    }
  }

  /// Starts continuous real-time GPS stream (triggers update when moving >= 5m)
  void startLiveTrackingStream() {
    _positionSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _currentLocation = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
          timestamp: DateTime.now(),
          isMockedOrFallback: false,
          label: 'Live Device GPS',
          isLiveTracking: true,
          address: _currentLocation.address,
        );
        _locationController.add(_currentLocation);
        _resolveAddress(position.latitude, position.longitude);
      },
      onError: (e) {
        debugPrint('Live tracking stream error: $e');
      },
    );
  }

  /// OpenStreetMap Reverse Geocoding API integration
  Future<void> _resolveAddress(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'ResQMesh-AI-DisasterApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String displayName = data['display_name'] ?? '';
        if (displayName.isNotEmpty) {
          // Format concise readable address
          final parts = displayName.split(',');
          final conciseAddress = parts.length > 3
              ? '${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}'
              : displayName;

          _currentLocation = _currentLocation.copyWith(address: conciseAddress);
          _locationController.add(_currentLocation);
        }
      }
    } catch (_) {
      // Offline fallback: keep existing address or fallback
    }
  }

  void updateSimulatedLocation(double lat, double lng, {String label = 'Custom Coordinates'}) {
    _positionSubscription?.cancel();
    _currentLocation = LocationData(
      latitude: lat,
      longitude: lng,
      accuracy: 5.0,
      timestamp: DateTime.now(),
      // Still flagged as non-GPS (so the UI never says STREAMING LIVE),
      // but explicitly confirmed by the user, so risk and SOS are
      // allowed to run on these coordinates.
      isMockedOrFallback: true,
      isManualConfirmed: true,
      label: label,
      address: 'Manual location — not live GPS',
      isLiveTracking: false,
    );
    _locationController.add(_currentLocation);
    _resolveAddress(lat, lng);
  }

  /// Explicit user-selected manual location. Marked confirmed (isMockedOrFallback = false)
  /// so that Home and SOS allow emergency actions.
  void updateManualLocation(double lat, double lng, {required String label}) {
    _positionSubscription?.cancel();
    _currentLocation = LocationData(
      latitude: lat,
      longitude: lng,
      accuracy: 10.0,
      timestamp: DateTime.now(),
      isMockedOrFallback: false,
      label: label,
      address: 'Manual Location Confirmed',
      isLiveTracking: false,
    );
    _locationController.add(_currentLocation);
    _resolveAddress(lat, lng);
  }

  // Phase 0 safety: random test-location generation is removed
  // entirely. Locations come from live GPS or explicit manual entry.

  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}
