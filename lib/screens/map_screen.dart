import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../models/location_data.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLocation();
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
      setState(() {
        _currentPosition = LatLng(initial.latitude, initial.longitude);
        _currentAccuracy = initial.accuracy;
        _isLoading = false;
      });
      _mapController.move(_currentPosition!, 16.0);
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
      });
      if (_isFollowing) {
        _mapController.move(_currentPosition!, _mapController.camera.zoom);
      }
    });

    await _locationService.startTracking();
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
              initialCenter: _currentPosition ?? const LatLng(37.5665, 126.9780),
              initialZoom: 16.0,
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
          // 위치 정보 표시
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Text(
                '위도: ${_currentPosition!.latitude.toStringAsFixed(6)}  '
                '경도: ${_currentPosition!.longitude.toStringAsFixed(6)}  '
                '정확도: ${_currentAccuracy.toStringAsFixed(0)}m',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          MapControlsWidget(
            isFollowing: _isFollowing,
            onCenterPressed: () {
              setState(() => _isFollowing = true);
              if (_currentPosition != null) {
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
