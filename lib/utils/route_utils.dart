import 'package:latlong2/latlong.dart';

class RouteUtils {
  /// Start → End arasında, durak sayısına göre ara noktalar üretir
  static List<LatLng> splitRoute({
    required LatLng start,
    required LatLng end,
    required int stops,
  }) {
    final List<LatLng> points = [];
    final int segments = stops + 1;

    for (int i = 1; i <= stops; i++) {
      final double t = i / segments;

      final double lat = start.latitude + (end.latitude - start.latitude) * t;
      final double lng =
          start.longitude + (end.longitude - start.longitude) * t;

      points.add(LatLng(lat, lng));
    }

    return points;
  }
}
