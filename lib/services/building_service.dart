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

/// 현재 위치가 어떤 건물 안에 있는지 찾기
Building? findCurrentBuilding(LatLng position, List<Building> buildings) {
  for (final building in buildings) {
    if (isPointInPolygon(position, building.polygon)) {
      return building;
    }
  }
  return null;
}
