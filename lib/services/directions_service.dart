import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DirectionsService {
  static const _baseUrl = 'https://router.project-osrm.org';

  /// OSRM ile GERÇEK yol mesafesi (km)
  /// fallback: kuş uçuşu
  static Future<double> getRouteDistanceKm(LatLng start, LatLng end) async {
    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=false',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        return const Distance().as(LengthUnit.Kilometer, start, end);
      }

      final data = jsonDecode(res.body);
      final meters = data['routes'][0]['distance'];
      return (meters as num).toDouble() / 1000.0;
    } catch (_) {
      return const Distance().as(LengthUnit.Kilometer, start, end);
    }
  }
}
