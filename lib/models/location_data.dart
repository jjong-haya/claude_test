import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

class LocationUpdate {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;

  LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.timestamp,
  });

  factory LocationUpdate.fromBgLocation(bg.Location location) {
    return LocationUpdate(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      accuracy: location.coords.accuracy,
      speed: location.coords.speed,
      heading: location.coords.heading,
      timestamp: DateTime.parse(location.timestamp),
    );
  }
}
