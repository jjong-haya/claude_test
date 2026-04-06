import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/building_service.dart';
import '../models/location_data.dart';
import '../models/building.dart';
import '../widgets/location_marker.dart';
import '../widgets/map_controls.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  StreamSubscription<LocationUpdate>? _locationSub;

  LatLng? _currentPosition;
  double _currentAccuracy = 0;
  bool _isFollowing = true;
  bool _isLoading = true;
  bool _mapReady = false;
  String? _error;

  List<Building> _buildings = [];
  String? _currentBuildingName;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // 건물 데이터 로드
    try {
      _buildings = await Building.loadFromAsset();
    } catch (_) {
      // 건물 데이터 로드 실패 시 빈 목록으로 진행
    }

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
      setState(() {
        _currentPosition = LatLng(initial.latitude, initial.longitude);
        _currentAccuracy = initial.accuracy;
        _isLoading = false;
        _updateCurrentBuilding();
      });
    } catch (e) {
      setState(() {
        _error = '위치를 가져올 수 없습니다: $e';
        _isLoading = false;
      });
      return;
    }

    _locationSub = _locationService.locationStream.listen((update) {
      setState(() {
        _currentPosition = LatLng(update.latitude, update.longitude);
        _currentAccuracy = update.accuracy;
        _updateCurrentBuilding();
      });
      if (_isFollowing && _mapReady) {
        _mapController.move(_currentPosition!, _mapController.camera.zoom);
      }
    });

    await _locationService.startTracking();
  }

  void _updateCurrentBuilding() {
    if (_currentPosition == null) return;
    final building = findCurrentBuilding(_currentPosition!, _buildings);
    _currentBuildingName = building?.name;
  }

  void _onMapReady() {
    _mapReady = true;
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('위치를 가져오는 중...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
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
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(37.6105, 126.9968),
              initialZoom: 16.0,
              onMapReady: _onMapReady,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _isFollowing) {
                  setState(() => _isFollowing = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.location_tracker',
              ),
              // 건물 폴리곤 레이어
              if (_buildings.isNotEmpty)
                PolygonLayer(
                  polygons: _buildings.map((b) {
                    final isInside = _currentBuildingName == b.name;
                    return Polygon(
                      points: b.polygon,
                      color: b.color.withValues(alpha: isInside ? 0.4 : 0.2),
                      borderColor: b.color,
                      borderStrokeWidth: isInside ? 3.0 : 1.5,
                      label: b.name,
                      labelStyle: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: isInside ? FontWeight.bold : FontWeight.normal,
                      ),
                      labelPlacement: PolygonLabelPlacement.centroid,
                    );
                  }).toList(),
                ),
              if (_currentPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentPosition!,
                      radius: _currentAccuracy,
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderColor: Colors.blue.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: const LocationMarkerWidget(),
                    ),
                  ],
                ),
            ],
          ),
          // 상단 정보바
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 현재 건물 표시
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
                  // 좌표 정보
                  Text(
                    '위도: ${_currentPosition!.latitude.toStringAsFixed(6)}  '
                    '경도: ${_currentPosition!.longitude.toStringAsFixed(6)}  '
                    '정확도: ${_currentAccuracy.toStringAsFixed(0)}m',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          MapControlsWidget(
            isFollowing: _isFollowing,
            onCenterPressed: () {
              setState(() => _isFollowing = true);
              if (_currentPosition != null && _mapReady) {
                _mapController.move(
                  _currentPosition!,
                  _mapController.camera.zoom,
                );
              }
            },
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
