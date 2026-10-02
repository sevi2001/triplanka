import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'booking_store.dart';

class TripMapScreen extends StatelessWidget {
  const TripMapScreen({
    super.key,
    required this.booking,
    this.loadMapTiles = true,
  });

  final TripBooking booking;
  final bool loadMapTiles;

  bool validCoordinates(TripCoordinates? coordinates) {
    return coordinates != null &&
        coordinates.latitude.isFinite &&
        coordinates.longitude.isFinite &&
        coordinates.latitude >= -90 &&
        coordinates.latitude <= 90 &&
        coordinates.longitude >= -180 &&
        coordinates.longitude <= 180;
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
              'Create a new planned trip using Search pickup '
              'and Search destination.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pickup = LatLng(
      pickupCoordinates!.latitude,
      pickupCoordinates.longitude,
    );

    final destination = LatLng(
      destinationCoordinates!.latitude,
      destinationCoordinates.longitude,
    );

    final samePoint =
        pickup.latitude == destination.latitude &&
        pickup.longitude == destination.longitude;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip map')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Pickup: ${booking.pickup}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Destination: ${booking.destination}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Saved pickup and destination locations. '
                    'Road routes and live tracking will be added later.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  if (booking.stops.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Stops are listed in your booking but are '
                      'not shown on this map yet.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                  if (samePoint) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Pickup and destination share the same map point.',
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: pickup,
                  initialZoom: 15,
                  initialCameraFit: samePoint
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds(pickup, destination),
                          padding: const EdgeInsets.all(60),
                          maxZoom: 16,
                        ),
                  minZoom: 3,
                  maxZoom: 19,
                ),
                children: [
                  if (loadMapTiles)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sevi2001.triplanka',
                    ),
                  MarkerLayer(
                    markers: [
                      locationMarker(
                        point: pickup,
                        label: 'Pickup: ${booking.pickup}',
                        color: Colors.teal,
                      ),
                      if (!samePoint)
                        locationMarker(
                          point: destination,
                          label: 'Destination: ${booking.destination}',
                          color: Colors.deepOrange,
                        ),
                    ],
                  ),
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
        ),
      ),
    );
  }
}
