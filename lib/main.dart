import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'app.dart';

@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent headlessEvent) async {
  // 앱이 종료된 상태에서도 위치 이벤트를 처리
  switch (headlessEvent.name) {
    case bg.Event.LOCATION:
      bg.Location location = headlessEvent.event;
      developer.log('[headless] location: ${location.coords.latitude}, ${location.coords.longitude}');
      break;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bg.BackgroundGeolocation.registerHeadlessTask(backgroundGeolocationHeadlessTask);
  runApp(const MyApp());
}
