import 'package:flutter/material.dart';

class MapControlsWidget extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onCenterPressed;

  const MapControlsWidget({
    super.key,
    required this.isFollowing,
    required this.onCenterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFollowing)
            FloatingActionButton(
              mini: true,
              onPressed: onCenterPressed,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
        ],
      ),
    );
  }
}
