import 'dart:async';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _locationController = StreamController<LocationUpdate>.broadcast();
  Stream<LocationUpdate> get locationStream => _locationController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  Future<bool> requestPermissions() async {
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return false;

    status = await Permission.locationAlways.request();
    // locationAlways가 거부되어도 포그라운드는 동작 가능
    return true;
  }

  Future<void> initialize() async {
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      _locationController.add(LocationUpdate.fromBgLocation(location));
    });

    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      _locationController.add(LocationUpdate.fromBgLocation(location));
    });

    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 5.0,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      foregroundService: true,
      notification: bg.Notification(
        title: "Location Tracker",
        text: "위치를 추적하고 있습니다",
        sticky: true,
      ),
      // iOS
      activityType: bg.Config.ACTIVITY_TYPE_FITNESS,
      pausesLocationUpdatesAutomatically: false,
    ));
  }

  Future<void> startTracking() async {
    await bg.BackgroundGeolocation.start();
    _isTracking = true;
  }

  Future<void> stopTracking() async {
    await bg.BackgroundGeolocation.stop();
    _isTracking = false;
  }

  Future<LocationUpdate> getCurrentLocation() async {
    final location = await bg.BackgroundGeolocation.getCurrentPosition(
      extras: {"event": "current-position"},
      maximumAge: 5000,
    );
    return LocationUpdate.fromBgLocation(location);
  }

  void dispose() {
    _locationController.close();
  }
}
