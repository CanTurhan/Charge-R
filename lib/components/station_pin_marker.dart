import 'package:flutter/material.dart';

class StationPinMarker extends StatelessWidget {
  const StationPinMarker({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Icon(
              Icons.location_on,
              size: size + 10,
              color: const Color(0xFFFFC400),
              shadows: const [
                Shadow(
                  blurRadius: 4,
                  offset: Offset(0, 2),
                  color: Colors.black45,
                ),
              ],
            ),
          ),
          Positioned(
            top: size * 0.23,
            child: Icon(
              Icons.bolt,
              size: size * 0.48,
              color: const Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }
}
