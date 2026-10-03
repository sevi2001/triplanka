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

    final locations = <TripCoordinates>[pickup!];

    for (int i = 0; i < booking.stops.length; i++) {
      final coordinates = booking.stopCoordinates[i];

      // Do not silently skip an intended stop.
      if (!validCoordinates(coordinates)) {
        throw Exception(
          'Stop ${i + 1} has no valid map location. '
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

    // OSRM expects longitude first, then latitude.
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
        'The routing service is unavailable. Please try again later.',
      );
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    final routes = data['routes'] as List<dynamic>?;

    if (data['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw Exception('No driving route was found for these locations.');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometry = Map<String, dynamic>.from(route['geometry'] as Map);

    final coordinates = geometry['coordinates'] as List<dynamic>;

    final points = coordinates.map((item) {
      final pair = item as List<dynamic>;

      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();

    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();

    if (points.length < 2 ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0) {
      throw Exception('The routing service returned an invalid route.');
    }

    return TripRoute(
      points: points,
      distanceMetres: distance,
      durationSeconds: duration,
    );
  }
}
