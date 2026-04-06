import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../services/location_service.dart';
import '../services/building_service.dart';
import '../services/kalman_filter.dart';
import '../models/location_data.dart';
import '../models/building.dart';

class MapboxMapScreen extends StatefulWidget {
  const MapboxMapScreen({super.key});

  @override
  State<MapboxMapScreen> createState() => _MapboxMapScreenState();
}

class _MapboxMapScreenState extends State<MapboxMapScreen> {
  final LocationService _locationService = LocationService();
  StreamSubscription<LocationUpdate>? _locationSub;

  MapboxMap? _mapboxMap;
  ll.LatLng? _currentPosition;
  double _currentAccuracy = 0;
  bool _isLoading = true;
  String? _error;

  List<Building> _buildings = [];
  String? _currentBuildingName;
  KalmanLatLng? _kalman;

  // 운동장 긴 면 기준 회전
  static const double _mapBearing = 36.4;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _initLocation();
  }

  Future<void> _loadBuildings() async {
    try {
      _buildings = await Building.loadFromAsset();
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    final granted = await _locationService.requestPermissions();
    if (!granted) {
      setState(() {
        _error = '위치 권한이 필요합니다.\n설정에서 위치 권한을 허용해주세요.';
        _isLoading = false;
      });
      return;
    }

    await _locationService.initialize();

    try {
      final initial = await _locationService.getCurrentLocation();
      final now = DateTime.now().millisecondsSinceEpoch;
      _kalman = KalmanLatLng(
        lat: initial.latitude,
        lng: initial.longitude,
        accuracy: initial.accuracy,
        timestamp: now,
      );
      setState(() {
        _currentPosition = ll.LatLng(_kalman!.latitude, _kalman!.longitude);
        _currentAccuracy = _kalman!.accuracy;
        _isLoading = false;
        _updateCurrentBuilding();
      });
      _flyToCurrentPosition();
    } catch (e) {
      setState(() {
        _error = '위치를 가져올 수 없습니다: $e';
        _isLoading = false;
      });
      return;
    }

    _locationSub = _locationService.locationStream.listen((update) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final (filteredLat, filteredLng) = _kalman!.update(
        lat: update.latitude,
        lng: update.longitude,
        accuracy: update.accuracy,
        timestamp: now,
      );
      setState(() {
        _currentPosition = ll.LatLng(filteredLat, filteredLng);
        _currentAccuracy = _kalman!.accuracy;
        _updateCurrentBuilding();
      });
      _updateLocationMarker();
    });

    await _locationService.startTracking();
  }

  void _updateCurrentBuilding() {
    if (_currentPosition == null) return;
    final building = findCurrentBuilding(_currentPosition!, _buildings);
    _currentBuildingName = building?.name;
  }

  void _flyToCurrentPosition() {
    if (_mapboxMap == null || _currentPosition == null) return;
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
        ),
        zoom: 16.5,
        bearing: _mapBearing,
        pitch: 45, // 3D 효과를 위한 기울기
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // 3D 건물 레이어 활성화는 스타일에 따라 자동
    // 건물 폴리곤 추가
    await _addBuildingPolygons();

    // 위치 마커 추가
    await _addLocationMarker();

    // 초기 카메라 설정
    if (_currentPosition != null) {
      _flyToCurrentPosition();
    }
  }

  Future<void> _addBuildingPolygons() async {
    if (_buildings.isEmpty || _mapboxMap == null) return;

    // GeoJSON 소스 생성
    final features = _buildings.map((b) {
      final coords = b.polygon
          .map((p) => [p.longitude, p.latitude])
          .toList();
      // 폴리곤 닫기
      coords.add(coords.first);

      return {
        "type": "Feature",
        "properties": {
          "name": b.name,
          "color": '#${b.color.toARGB32().toRadixString(16).substring(2)}',
        },
        "geometry": {
          "type": "Polygon",
          "coordinates": [coords],
        },
      };
    }).toList();

    final geojson = json.encode({
      "type": "FeatureCollection",
      "features": features,
    });

    // 소스 추가
    await _mapboxMap!.style.addSource(
      GeoJsonSource(id: "campus-buildings", data: geojson),
    );

    // 건물 채우기 레이어
    await _mapboxMap!.style.addLayer(
      FillLayer(
        id: "campus-buildings-fill",
        sourceId: "campus-buildings",
        fillColor: Colors.blue.toARGB32(),
        fillOpacity: 0.25,
      ),
    );

    // 건물 테두리 레이어
    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: "campus-buildings-line",
        sourceId: "campus-buildings",
        lineColor: Colors.blue.toARGB32(),
        lineWidth: 2.0,
      ),
    );

    // 건물 이름 라벨 레이어
    await _mapboxMap!.style.addLayer(
      SymbolLayer(
        id: "campus-buildings-label",
        sourceId: "campus-buildings",
        textField: "{name}",
        textSize: 12.0,
        textColor: Colors.black.toARGB32(),
        textHaloColor: Colors.white.toARGB32(),
        textHaloWidth: 1.5,
      ),
    );
  }

  Future<void> _addLocationMarker() async {
    if (_mapboxMap == null || _currentPosition == null) return;

    final geojson = json.encode({
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "Point",
            "coordinates": [
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ],
          },
        }
      ],
    });

    // 소스가 이미 있으면 업데이트, 없으면 추가
    try {
      await _mapboxMap!.style.getSource("user-location");
      // 이미 있으면 데이터 업데이트
      final source = await _mapboxMap!.style.getSource("user-location");
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geojson);
      }
    } catch (_) {
      // 없으면 새로 추가
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: "user-location", data: geojson),
      );

      // 정확도 원
      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: "user-location-accuracy",
          sourceId: "user-location",
          circleRadius: 30.0,
          circleColor: Colors.blue.withValues(alpha: 0.15).toARGB32(),
          circleStrokeColor: Colors.blue.withValues(alpha: 0.3).toARGB32(),
          circleStrokeWidth: 1.0,
        ),
      );

      // 위치 점
      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: "user-location-dot",
          sourceId: "user-location",
          circleRadius: 8.0,
          circleColor: Colors.blue.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3.0,
        ),
      );
    }
  }

  Future<void> _updateLocationMarker() async {
    if (_mapboxMap == null || _currentPosition == null) return;

    final geojson = json.encode({
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "Point",
            "coordinates": [
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ],
          },
        }
      ],
    });

    try {
      final source = await _mapboxMap!.style.getSource("user-location");
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geojson);
      }
    } catch (_) {
      await _addLocationMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapbox 3D 맵
          MapWidget(
            key: const ValueKey("mapbox"),
            mapOptions: MapOptions(
              pixelRatio: MediaQuery.of(context).devicePixelRatio,
            ),
            styleUri: MapboxStyles.STANDARD,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(126.9968, 37.6105),
              ),
              zoom: 16.5,
              bearing: _mapBearing,
              pitch: 45,
            ),
            onMapCreated: _onMapCreated,
          ),

          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.white70,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('위치를 가져오는 중...'),
                  ],
                ),
              ),
            ),

          // 에러 오버레이
          if (_error != null)
            Container(
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _initLocation();
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 상단 정보바
          if (_currentPosition != null && !_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentBuildingName != null
                              ? Icons.apartment
                              : Icons.park,
                          size: 18,
                          color: _currentBuildingName != null
                              ? Colors.blue
                              : Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentBuildingName != null
                              ? '현재 위치: $_currentBuildingName'
                              : '현재 위치: 실외',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '위도: ${_currentPosition!.latitude.toStringAsFixed(6)}  '
                      '경도: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),

          // 재중심 버튼
          if (_currentPosition != null && !_isLoading)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _flyToCurrentPosition,
                child: const Icon(Icons.my_location, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }
}
