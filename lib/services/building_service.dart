import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/building.dart';

/// Ray-casting 알고리즘으로 점이 폴리곤 안에 있는지 판별
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  bool inside = false;
  int j = polygon.length - 1;

  for (int i = 0; i < polygon.length; i++) {
    final xi = polygon[i].latitude;
    final yi = polygon[i].longitude;
    final xj = polygon[j].latitude;
    final yj = polygon[j].longitude;

    final intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
        (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);

    if (intersect) inside = !inside;
    j = i;
  }

  return inside;
}

/// 점에서 폴리곤 가장 가까운 변까지의 최소 거리 (미터)
double distanceToPolygon(LatLng point, List<LatLng> polygon) {
  double minDist = double.infinity;

  for (int i = 0; i < polygon.length; i++) {
    final j = (i + 1) % polygon.length;
    final dist = _distanceToSegment(point, polygon[i], polygon[j]);
    if (dist < minDist) minDist = dist;
  }

  return minDist;
}

/// 점에서 선분(a-b)까지의 최소 거리 (미터)
double _distanceToSegment(LatLng point, LatLng a, LatLng b) {
  final px = point.latitude;
  final py = point.longitude;
  final ax = a.latitude;
  final ay = a.longitude;
  final bx = b.latitude;
  final by = b.longitude;

  final dx = bx - ax;
  final dy = by - ay;
  final lenSq = dx * dx + dy * dy;

  double t = 0;
  if (lenSq > 0) {
    t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
  }

  final closestLat = ax + t * dx;
  final closestLng = ay + t * dy;

  // 위도/경도 차이를 미터로 변환 (근사치)
  final dLat = (px - closestLat) * 111320;
  final dLng = (py - closestLng) * 111320 * cos(px * pi / 180);

  return sqrt(dLat * dLat + dLng * dLng);
}

/// 현재 위치가 어떤 건물 안에 있는지 찾기 (5m 여유 포함)
Building? findCurrentBuilding(LatLng position, List<Building> buildings) {
  const double marginMeters = 5.0;

  for (final building in buildings) {
    // 폴리곤 내부이거나, 경계에서 5m 이내면 해당 건물로 판정
    if (isPointInPolygon(position, building.polygon) ||
        distanceToPolygon(position, building.polygon) <= marginMeters) {
      return building;
    }
  }
  return null;
}
