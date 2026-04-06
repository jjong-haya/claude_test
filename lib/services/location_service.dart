import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';

// 조건부 임포트: 웹이면 web_location.dart, 아니면 stub_location.dart
import 'stub_location.dart'
    if (dart.library.js_interop) 'web_location.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _locationController = StreamController<LocationUpdate>.broadcast();
  Stream<LocationUpdate> get locationStream => _locationController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  int? _webWatchId;

  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      // 웹에서는 브라우저가 자체적으로 권한 요청 처리
      return true;
    }

    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return false;

    status = await Permission.locationAlways.request();
    return true;
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

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
      activityType: bg.Config.ACTIVITY_TYPE_FITNESS,
      pausesLocationUpdatesAutomatically: false,
    ));
  }

  Future<void> startTracking() async {
    if (kIsWeb) {
      _webWatchId = watchWebPosition((update) {
        _locationController.add(update);
      });
      _isTracking = true;
      return;
    }

    await bg.BackgroundGeolocation.start();
    _isTracking = true;
  }

  Future<void> stopTracking() async {
    if (kIsWeb) {
      if (_webWatchId != null) {
        clearWebWatch(_webWatchId!);
        _webWatchId = null;
      }
      _isTracking = false;
      return;
    }

    await bg.BackgroundGeolocation.stop();
    _isTracking = false;
  }

  Future<LocationUpdate> getCurrentLocation() async {
    if (kIsWeb) {
      return getWebCurrentLocation();
    }

    final location = await bg.BackgroundGeolocation.getCurrentPosition(
      extras: {"event": "current-position"},
      maximumAge: 5000,
    );
    return LocationUpdate.fromBgLocation(location);
  }

  void dispose() {
    if (_webWatchId != null) {
      clearWebWatch(_webWatchId!);
    }
    _locationController.close();
  }
}
