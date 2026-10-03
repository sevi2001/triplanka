import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'booking_store.dart';
import 'route_service.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({
    super.key,
    required this.booking,
    this.loadMapTiles = true,
  });

  final TripBooking booking;
  final bool loadMapTiles;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final mapController = MapController();

  TripRoute? route;
  bool calculating = false;
  bool mapReady = false;
  String? routeError;

  TripBooking get booking => widget.booking;

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  bool validCoordinates(TripCoordinates? coordinates) {
    return RouteService.validCoordinates(coordinates);
  }

  LatLng mapPoint(TripCoordinates coordinates) {
    return LatLng(coordinates.latitude, coordinates.longitude);
  }

  String durationLabel(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';

    return '$hours hr $minutes min';
  }

  Future<void> calculateRoute() async {
    if (calculating) return;

    setState(() {
      calculating = true;
      routeError = null;
    });

    try {
      final result = await RouteService.fetchRoute(booking);

      if (!mounted) return;

      setState(() {
        route = result;
      });

      if (mapReady) {
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(result.points),
            padding: const EdgeInsets.all(60),
            maxZoom: 16,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        routeError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          calculating = false;
        });
      }
    }
  }

  Marker locationMarker({
    required LatLng point,
    required String label,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Tooltip(
        message: label,
        child: Icon(Icons.location_on, color: color, size: 44),
      ),
    );
  }

  Marker stopMarker({
    required LatLng point,
    required int number,
    required String name,
  }) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Tooltip(
        message: 'Stop $number: $name',
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget locationRow({
    required String title,
    required String name,
    required Color color,
    String? number,
    bool missingCoordinates = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number == null)
            Icon(Icons.location_on, color: color)
          else
            CircleAvatar(
              radius: 12,
              backgroundColor: color,
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title: $name'),
                if (missingCoordinates)
                  const Text(
                    'Map location not saved for this stop.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickupCoordinates = booking.pickupCoordinates;
    final destinationCoordinates = booking.destinationCoordinates;

    if (!validCoordinates(pickupCoordinates) ||
        !validCoordinates(destinationCoordinates)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip map')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This booking does not have both map locations. '
              'Create a new booking using location search.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pickup = mapPoint(pickupCoordinates!);
    final destination = mapPoint(destinationCoordinates!);

    final sameEndpoints =
        pickup.latitude == destination.latitude &&
        pickup.longitude == destination.longitude;

    final points = <LatLng>[pickup, destination];

    final markers = <Marker>[
      locationMarker(
        point: pickup,
        label: sameEndpoints
            ? 'Pickup and return: ${booking.pickup}'
            : 'Pickup: ${booking.pickup}',
        color: Colors.teal,
      ),
      if (!sameEndpoints)
        locationMarker(
          point: destination,
          label: 'Destination: ${booking.destination}',
          color: Colors.deepOrange,
        ),
    ];

    int mappedStops = 0;

    for (int i = 0; i < booking.stops.length; i++) {
      final coordinates = booking.stopCoordinates[i];

      if (!validCoordinates(coordinates)) continue;

      final point = mapPoint(coordinates!);

      points.add(point);
      markers.add(
        stopMarker(point: point, number: i + 1, name: booking.stops[i]),
      );

      mappedStops++;
    }

    final allSamePoint = points.every(
      (point) =>
          point.latitude == pickup.latitude &&
          point.longitude == pickup.longitude,
    );

    final allStopsMapped = mappedStops == booking.stops.length;
    final canCalculate = allStopsMapped && !allSamePoint;
    final currentRoute = route;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip map')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.45,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        locationRow(
                          title: 'Pickup',
                          name: booking.pickup,
                          color: Colors.teal,
                        ),
                        for (int i = 0; i < booking.stops.length; i++)
                          locationRow(
                            title: 'Stop ${i + 1}',
                            name: booking.stops[i],
                            color: Colors.blue,
                            number: '${i + 1}',
                            missingCoordinates: !validCoordinates(
                              booking.stopCoordinates[i],
                            ),
                          ),
                        locationRow(
                          title: sameEndpoints
                              ? 'Return destination'
                              : 'Destination',
                          name: booking.destination,
                          color: sameEndpoints
                              ? Colors.teal
                              : Colors.deepOrange,
                        ),
                        if (!allStopsMapped) ...[
                          const Text(
                            'Route calculation needs map locations for '
                            'every stop. Create a new booking and use '
                            'Search for each stop.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (allSamePoint) ...[
                          const Text(
                            'Route calculation needs at least two '
                            'different map locations.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (currentRoute != null) ...[
                          Text(
                            'Distance: '
                            '${currentRoute.distanceKilometres.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Estimated driving time: '
                            '${durationLabel(currentRoute.durationMinutes)}',
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (routeError != null) ...[
                          Text(
                            routeError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        FilledButton.icon(
                          onPressed: calculating || !canCalculate
                              ? null
                              : calculateRoute,
                          icon: calculating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.route),
                          label: Text(
                            calculating
                                ? 'Calculating...'
                                : currentRoute == null
                                ? 'Calculate route'
                                : 'Recalculate route',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Calculation sends selected locations to the '
                          'OSRM demo routing service. This is a general '
                          'driving estimate, excluding visits and waiting. '
                          'Vehicle restrictions and live traffic '
                          'are not checked by this app.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The map shows the saved outbound journey. '
                          'A separately scheduled return leg is not '
                          'included in this calculation.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: pickup,
                      initialZoom: 15,
                      initialCameraFit: allSamePoint
                          ? null
                          : CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(points),
                              padding: const EdgeInsets.all(60),
                              maxZoom: 16,
                            ),
                      onMapReady: () {
                        mapReady = true;
                      },
                      minZoom: 3,
                      maxZoom: 19,
                    ),
                    children: [
                      if (widget.loadMapTiles)
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sevi2001.triplanka',
                        ),
                      if (currentRoute != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: currentRoute.points,
                              color: Colors.blue,
                              strokeWidth: 5,
                            ),
                          ],
                        ),
                      MarkerLayer(markers: markers),
                      const Align(
                        alignment: Alignment.bottomRight,
                        child: ColoredBox(
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
