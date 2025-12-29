import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static Future<LatLng?> addressToLatLng(String address) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(address)}'
      '&format=json'
      '&limit=1',
    );

    final res = await http.get(
      uri,
      headers: {'User-Agent': 'Charge-R Flutter App'},
    );

    if (res.statusCode != 200) return null;

    final List data = jsonDecode(res.body);
    if (data.isEmpty) return null;

    return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
  }
}
