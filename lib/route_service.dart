import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'booking_store.dart';

class TripRoute {
  TripRoute({
    required List<LatLng> points,
    required this.distanceMetres,
    required this.durationSeconds,
  }) : points = List<LatLng>.unmodifiable(points);

  final List<LatLng> points;
  final double distanceMetres;
  final double durationSeconds;

  double get distanceKilometres => distanceMetres / 1000;

  int get durationMinutes => (durationSeconds / 60).ceil();
}

class RouteService {
  RouteService._();

  static bool validCoordinates(TripCoordinates? coordinates) {
    return coordinates != null &&
        coordinates.latitude.isFinite &&
        coordinates.longitude.isFinite &&
        coordinates.latitude >= -90 &&
        coordinates.latitude <= 90 &&
        coordinates.longitude >= -180 &&
        coordinates.longitude <= 180;
  }

  static Future<TripRoute> fetchRoute(TripBooking booking) async {
    final pickup = booking.pickupCoordinates;
    final destination = booking.destinationCoordinates;

    if (!validCoordinates(pickup) || !validCoordinates(destination)) {
      throw Exception('Pickup and destination need selected map locations.');
    }

    if (booking.stopCoordinates.length != booking.stops.length) {
      throw Exception('The saved stop locations do not match the trip stops.');
    }

    final locations = <TripCoordinates>[pickup!];

    for (int i = 0; i < booking.stops.length; i++) {
      final coordinates = booking.stopCoordinates[i];

      if (!validCoordinates(coordinates)) {
        throw Exception(
          'Stop ${i + 1} needs a selected map location. '
          'Create a new booking using Search for every stop.',
        );
      }

      locations.add(coordinates!);
    }

    locations.add(destination!);

    final first = locations.first;
    final allSamePoint = locations.every(
      (point) =>
          point.latitude == first.latitude &&
          point.longitude == first.longitude,
    );

    if (allSamePoint) {
      throw Exception('Choose at least two different map locations.');
    }

    // OSRM expects longitude before latitude.
    final coordinatePath = locations
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');

    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinatePath',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': 'false',
      },
    );

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'The routing service is unavailable. '
        'Please try again later.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map) {
      throw const FormatException('Invalid routing response.');
    }

    final routes = decoded['routes'];

    if (decoded['code'] != 'Ok' || routes is! List || routes.isEmpty) {
      throw Exception('No driving route was found for these locations.');
    }

    final route = routes.first;

    if (route is! Map) {
      throw const FormatException('Invalid route data.');
    }

    final geometry = route['geometry'];

    if (geometry is! Map || geometry['type'] != 'LineString') {
      throw const FormatException('Invalid route geometry.');
    }

    final coordinates = geometry['coordinates'];
    final distanceValue = route['distance'];
    final durationValue = route['duration'];

    if (coordinates is! List ||
        distanceValue is! num ||
        durationValue is! num) {
      throw const FormatException('Incomplete route data.');
    }

    final points = <LatLng>[];

    for (final item in coordinates) {
      if (item is! List ||
          item.length < 2 ||
          item[0] is! num ||
          item[1] is! num) {
        throw const FormatException('Invalid route coordinate.');
      }

      final longitude = (item[0] as num).toDouble();
      final latitude = (item[1] as num).toDouble();

      if (!validCoordinates(
        TripCoordinates(latitude: latitude, longitude: longitude),
      )) {
        throw const FormatException(
          'Route coordinate is outside the valid range.',
        );
      }

      points.add(LatLng(latitude, longitude));
    }

    final distance = distanceValue.toDouble();
    final duration = durationValue.toDouble();

    if (points.length < 2 ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0) {
      throw const FormatException(
        'The routing service returned an invalid route.',
      );
    }

    return TripRoute(
      points: points,
      distanceMetres: distance,
      durationSeconds: duration,
    );
  }
}
