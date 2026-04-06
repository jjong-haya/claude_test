import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class Building {
  final String id;
  final String name;
  final List<LatLng> polygon;
  final Color color;

  Building({
    required this.id,
    required this.name,
    required this.polygon,
    required this.color,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    final colorHex = (json['color'] as String).replaceFirst('#', '');
    final color = Color(int.parse('FF$colorHex', radix: 16));

    final coords = (json['polygon'] as List)
        .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();

    return Building(
      id: json['id'] as String,
      name: json['name'] as String,
      polygon: coords,
      color: color,
    );
  }

  static Future<List<Building>> loadFromAsset() async {
    final jsonStr = await rootBundle.loadString('assets/buildings.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final buildings = (data['buildings'] as List)
        .map((b) => Building.fromJson(b as Map<String, dynamic>))
        .toList();
    return buildings;
  }
}
