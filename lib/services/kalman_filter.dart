import 'dart:math';

/// GPS 좌표에 대한 1차원 칼만 필터
/// 위도, 경도 각각에 적용
class KalmanLatLng {
  double _lat;
  double _lng;
  double _variance; // 현재 추정의 불확실성 (미터² 단위)
  int _timestamp;   // 마지막 업데이트 시각 (밀리초)

  static const double _minAccuracy = 1.0; // 최소 정확도 (미터)

  KalmanLatLng({
    required double lat,
    required double lng,
    required double accuracy,
    required int timestamp,
  })  : _lat = lat,
        _lng = lng,
        _variance = accuracy * accuracy,
        _timestamp = timestamp;

  /// 새 GPS 측정값으로 필터 업데이트
  /// 반환: (filteredLat, filteredLng)
  (double, double) update({
    required double lat,
    required double lng,
    required double accuracy,
    required int timestamp,
  }) {
    final acc = max(accuracy, _minAccuracy);

    if (_variance < 0) {
      // 첫 측정 — 초기화
      _lat = lat;
      _lng = lng;
      _variance = acc * acc;
      _timestamp = timestamp;
      return (_lat, _lng);
    }

    // 시간 경과에 따른 불확실성 증가 (process noise)
    final dt = timestamp - _timestamp;
    if (dt > 0) {
      // 보행 속도 ~1.4m/s 기준, 분산 증가
      // Q = velocity² * dt² (단위: 미터²)
      // dt를 밀리초→초 변환
      final dtSec = dt / 1000.0;
      _variance += dtSec * dtSec * 1.96; // 1.4² ≈ 1.96
      _timestamp = timestamp;
    }

    // 칼만 이득 (Kalman gain)
    final measurementVariance = acc * acc;
    final k = _variance / (_variance + measurementVariance);

    // 상태 업데이트
    _lat += k * (lat - _lat);
    _lng += k * (lng - _lng);
    _variance = (1 - k) * _variance;

    return (_lat, _lng);
  }

  double get latitude => _lat;
  double get longitude => _lng;

  /// 현재 추정 정확도 (미터)
  double get accuracy => sqrt(_variance);
}
