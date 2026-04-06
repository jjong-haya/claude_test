import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'app.dart';

// Mapbox 토큰은 환경변수 또는 --dart-define으로 전달
// 실행: flutter run --dart-define=MAPBOX_TOKEN=pk.eyJ...
const String _mapboxToken = String.fromEnvironment(
  'MAPBOX_TOKEN',
  defaultValue: '',
);

@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent headlessEvent) async {
  if (headlessEvent.name == bg.Event.LOCATION) {
    bg.Location location = headlessEvent.event;
    debugPrint('[headless] location: ${location.coords.latitude}, ${location.coords.longitude}');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Mapbox 토큰 설정
  if (_mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxToken);
  }

  // headless task는 모바일에서만 등록
  if (!kIsWeb) {
    bg.BackgroundGeolocation.registerHeadlessTask(backgroundGeolocationHeadlessTask);
  }

  runApp(const MyApp());
}
