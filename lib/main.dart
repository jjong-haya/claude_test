import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'app.dart';

@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent headlessEvent) async {
  if (headlessEvent.name == bg.Event.LOCATION) {
    bg.Location location = headlessEvent.event;
    debugPrint('[headless] location: ${location.coords.latitude}, ${location.coords.longitude}');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // headless task는 모바일에서만 등록 (웹에서는 지원 안 됨)
  if (!kIsWeb) {
    bg.BackgroundGeolocation.registerHeadlessTask(backgroundGeolocationHeadlessTask);
  }

  runApp(const MyApp());
}
