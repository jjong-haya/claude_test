import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/location_data.dart';

Future<LocationUpdate> getWebCurrentLocation() async {
  final completer = Completer<LocationUpdate>();

  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition position) {
      completer.complete(LocationUpdate(
        latitude: position.coords.latitude.toDouble(),
        longitude: position.coords.longitude.toDouble(),
        accuracy: position.coords.accuracy.toDouble(),
        speed: (position.coords.speed ?? 0).toDouble(),
        heading: (position.coords.heading ?? 0).toDouble(),
        timestamp: DateTime.now(),
      ));
    }).toJS,
    ((web.GeolocationPositionError error) {
      completer.completeError('위치를 가져올 수 없습니다: ${error.message}');
    }).toJS,
    web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: 5000,
    ),
  );

  return completer.future;
}

int watchWebPosition(void Function(LocationUpdate) onUpdate) {
  return web.window.navigator.geolocation.watchPosition(
    ((web.GeolocationPosition position) {
      onUpdate(LocationUpdate(
        latitude: position.coords.latitude.toDouble(),
        longitude: position.coords.longitude.toDouble(),
        accuracy: position.coords.accuracy.toDouble(),
        speed: (position.coords.speed ?? 0).toDouble(),
        heading: (position.coords.heading ?? 0).toDouble(),
        timestamp: DateTime.now(),
      ));
    }).toJS,
    ((web.GeolocationPositionError error) {
      // 에러 시 무시
    }).toJS,
    web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: 5000,
    ),
  );
}

void clearWebWatch(int watchId) {
  web.window.navigator.geolocation.clearWatch(watchId);
}
