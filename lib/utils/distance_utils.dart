import 'package:latlong2/latlong.dart';

class DistanceUtils {
  static final Distance _distance = Distance();

  static double kmBetween(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Kilometer, a, b);
  }
}
