import 'package:latlong2/latlong.dart';
import 'open_charge_map_service.dart';

class RoutePlanner {
  static Future<List<OcmStation>> suggestStops({
    required LatLng start,
    required LatLng destination,
    required double maxRangeKm,
  }) async {
    // v1: orta noktadan istasyon öner
    final midLat = (start.latitude + destination.latitude) / 2;
    final midLng = (start.longitude + destination.longitude) / 2;

    final stations = await OpenChargeMapService.fetchNearby(
      lat: midLat,
      lng: midLng,
      distanceKm: 30,
    );

    return stations.take(2).toList();
  }
}
