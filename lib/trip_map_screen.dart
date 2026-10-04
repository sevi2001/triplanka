import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'booking_store.dart';
import 'route_service.dart';
import 'travel_safety_screen.dart';

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

  bool validCoordinates(TripCoordinates? point) {
    return point != null &&
        point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  LatLng mapPoint(TripCoordinates point) {
    return LatLng(point.latitude, point.longitude);
  }

  List<LatLng> get savedPoints {
    return [
      if (validCoordinates(booking.pickupCoordinates))
        mapPoint(booking.pickupCoordinates!),
      for (final point in booking.stopCoordinates)
        if (validCoordinates(point)) mapPoint(point!),
      if (validCoordinates(booking.destinationCoordinates))
        mapPoint(booking.destinationCoordinates!),
    ];
  }

  bool get hasAllLocations {
    return validCoordinates(booking.pickupCoordinates) &&
        validCoordinates(booking.destinationCoordinates) &&
        booking.stopCoordinates.every(validCoordinates);
  }

  bool allPointsEqual(List<LatLng> points) {
    if (points.isEmpty) return true;

    return points.every(
      (point) =>
          point.latitude == points.first.latitude &&
          point.longitude == points.first.longitude,
    );
  }

  String formatDuration(double seconds) {
    final minutes = (seconds / 60).ceil();
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) return '$minutes min';
    if (remaining == 0) return '$hours hr';

    return '$hours hr $remaining min';
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  Future<void> calculateRoute() async {
    if (calculating) return;

    if (!hasAllLocations) {
      setState(() {
        routeError =
            'Select map locations for pickup, destination, '
            'and every stop to calculate a road route.';
      });
      return;
    }

    if (allPointsEqual(savedPoints)) {
      setState(() {
        routeError = 'Choose different locations for your journey.';
      });
      return;
    }

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

      if (mapReady && result.points.isNotEmpty) {
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(result.points),
            padding: const EdgeInsets.all(48),
            maxZoom: 16,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      debugPrint('Route calculation failed: $error');

      setState(() {
        routeError =
            'Could not load the road route. '
            'Check your connection and tap Try again.';
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
    required Color color,
    required String label,
    String? number,
  }) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Tooltip(
        message: label,
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: number == null
                ? const Icon(Icons.location_on, color: Colors.white, size: 21)
                : Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget locationRow({
    required String title,
    required String location,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, color: color, size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                location,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget metric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2563EB), size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = savedPoints;

    if (!validCoordinates(booking.pickupCoordinates) ||
        !validCoordinates(booking.destinationCoordinates)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your trip')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This booking needs pickup and destination '
              'map locations. Create a new booking using '
              'Search pickup and Search destination.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pickup = mapPoint(booking.pickupCoordinates!);
    final destination = mapPoint(booking.destinationCoordinates!);
    final sameEndpoints =
        pickup.latitude == destination.latitude &&
        pickup.longitude == destination.longitude;
    final loadedRoute = route;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF0F7),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'Your trip',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14213D),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Travel safety',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TravelSafetyScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.health_and_safety_outlined),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: pickup,
                        initialZoom: 14,
                        initialCameraFit: allPointsEqual(points)
                            ? null
                            : CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints(points),
                                padding: const EdgeInsets.all(48),
                                maxZoom: 16,
                              ),
                        minZoom: 3,
                        maxZoom: 19,
                        onMapReady: () {
                          mapReady = true;

                          // Avoid network routing in tile-free tests.
                          if (widget.loadMapTiles) {
                            calculateRoute();
                          }
                        },
                      ),
                      children: [
                        if (widget.loadMapTiles)
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/'
                                '{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.sevi2001.triplanka',
                          ),
                        if (loadedRoute != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: loadedRoute.points,
                                color: const Color(0xFF2563EB),
                                strokeWidth: 6,
                                borderColor: Colors.white,
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            locationMarker(
                              point: pickup,
                              color: const Color(0xFF0D9488),
                              label: sameEndpoints
                                  ? 'Pickup and return location'
                                  : 'Pickup',
                            ),
                            for (
                              int i = 0;
                              i < booking.stopCoordinates.length;
                              i++
                            )
                              if (validCoordinates(booking.stopCoordinates[i]))
                                locationMarker(
                                  point: mapPoint(booking.stopCoordinates[i]!),
                                  color: const Color(0xFF2563EB),
                                  label: booking.stops[i],
                                  number: '${i + 1}',
                                ),
                            if (!sameEndpoints)
                              locationMarker(
                                point: destination,
                                color: const Color(0xFFF43F5E),
                                label: 'Destination',
                              ),
                          ],
                        ),
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: ColoredBox(
                            color: Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                '© OpenStreetMap contributors',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.48,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDFE4EC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your journey',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14213D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${booking.vehicle} • '
                            '${booking.passengers} passengers',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              metric(
                                icon: Icons.route,
                                value: loadedRoute == null
                                    ? '—'
                                    : '${(loadedRoute.distanceMetres / 1000).toStringAsFixed(1)} km',
                                label: 'Road distance',
                              ),
                              const SizedBox(width: 12),
                              metric(
                                icon: Icons.schedule,
                                value: loadedRoute == null
                                    ? '—'
                                    : formatDuration(
                                        loadedRoute.durationSeconds,
                                      ),
                                label: 'Estimated driving',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          locationRow(
                            title: 'PICKUP',
                            location: booking.pickup,
                            color: const Color(0xFF0D9488),
                          ),
                          const SizedBox(height: 14),
                          locationRow(
                            title: 'DESTINATION',
                            location: booking.destination,
                            color: const Color(0xFFF43F5E),
                          ),
                          if (booking.stops.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Stops: ${booking.stops.join(' → ')}'),
                          ],
                          if (routeError != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              routeError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: calculating ? null : calculateRoute,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
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
                                    ? 'Finding road route...'
                                    : routeError != null
                                    ? 'Try again'
                                    : loadedRoute == null
                                    ? 'Calculate route'
                                    : 'Refresh route',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TravelSafetyScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.health_and_safety_outlined,
                              ),
                              label: const Text('Travel safety'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Demo booking • No driver assigned',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Route estimation sends selected locations '
                            'to the OSRM demo service. Driving time '
                            'excludes live traffic, visits, waiting, '
                            'and a separately scheduled return journey.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
