import 'dart:async';
import '../models/location_data.dart';

// 모바일에서는 이 파일이 임포트됨 (웹 전용 함수의 스텁)
Future<LocationUpdate> getWebCurrentLocation() async {
  throw UnsupportedError('Web location is not supported on this platform');
}

int watchWebPosition(void Function(LocationUpdate) onUpdate) {
  throw UnsupportedError('Web location is not supported on this platform');
}

void clearWebWatch(int watchId) {
  throw UnsupportedError('Web location is not supported on this platform');
}
