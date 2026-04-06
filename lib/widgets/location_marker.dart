import 'package:flutter/material.dart';

class LocationMarkerWidget extends StatelessWidget {
  const LocationMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
