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

  LatLng mapPoint(TripCoordinates coordinates) {
    return LatLng(coordinates.latitude, coordinates.longitude);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Trip map')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Keep long place names and stop lists scrollable
                // so there is still space for the map.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.4,
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
                        if (booking.stops.isNotEmpty) ...[
                          Text(
                            '$mappedStops of ${booking.stops.length} '
                            'stops have map locations.',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Text(
                          'Saved locations only. Road routes and '
                          'live tracking will be added later.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        if (sameEndpoints) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Pickup and return share one teal marker.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FlutterMap(
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
