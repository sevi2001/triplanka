import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_store.dart';
import 'route_service.dart';
import 'travel_safety_screen.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({
    super.key,
    required this.booking,
    this.requestId,
    this.loadMapTiles = true,
  });

  final TripBooking booking;
  final String? requestId;
  final bool loadMapTiles;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const green = Color(0xFF159A75);
  static const red = Color(0xFFD94D64);

  final mapController = MapController();

  Stream<DocumentSnapshot<Map<String, dynamic>>>? requestStream;
  StreamSubscription<User?>? authSubscription;

  String? accountId;
  int requestVersion = 0;

  TripRoute? route;
  bool calculating = false;
  bool mapReady = false;
  bool openingPhone = false;
  String? routeError;

  TripBooking get booking => widget.booking;

  bool get hasRequest => widget.requestId?.trim().isNotEmpty == true;

  bool get accountMatches =>
      !hasRequest ||
      (accountId != null &&
          FirebaseAuth.instance.currentUser?.uid == accountId);

  @override
  void initState() {
    super.initState();

    if (hasRequest) {
      accountId = FirebaseAuth.instance.currentUser?.uid;
      prepareRequest();

      authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  void prepareRequest() {
    requestVersion++;

    requestStream = !hasRequest || accountId == null
        ? null
        : FirebaseFirestore.instance
              .collection('tripRequests')
              .doc(widget.requestId!.trim())
              .snapshots();
  }

  void retryRequest() {
    if (!accountMatches) return;
    setState(prepareRequest);
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  String readText(Map<String, dynamic>? data, String key) {
    final value = data?[key];
    return value is String ? value.trim() : '';
  }

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

  List<LatLng> get savedPoints => [
    if (validCoordinates(booking.pickupCoordinates))
      mapPoint(booking.pickupCoordinates!),
    for (final point in booking.stopCoordinates)
      if (validCoordinates(point)) mapPoint(point!),
    if (validCoordinates(booking.destinationCoordinates))
      mapPoint(booking.destinationCoordinates!),
  ];

  bool get hasAllLocations =>
      validCoordinates(booking.pickupCoordinates) &&
      validCoordinates(booking.destinationCoordinates) &&
      booking.stopCoordinates.length == booking.stops.length &&
      booking.stopCoordinates.every(validCoordinates);

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

  Future<void> calculateRoute() async {
    if (calculating || !accountMatches) return;

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

      if (!mounted || !accountMatches) return;

      setState(() => route = result);

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
      if (!mounted || !accountMatches) return;

      debugPrint('Route calculation failed: $error');

      setState(() {
        routeError =
            'Could not load the road route. '
            'Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => calculating = false);
      }
    }
  }

  void showMessage(String message) {
    if (!mounted || !accountMatches) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> callDriver(String phone) async {
    if (openingPhone || !accountMatches) return;

    final number = phone.trim().replaceAll(RegExp(r'[\s()-]'), '');

    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(number)) {
      showMessage('The driver phone number is unavailable or invalid.');
      return;
    }

    setState(() => openingPhone = true);

    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: number));

      if (!mounted || !accountMatches) return;

      if (!opened) {
        showMessage(
          'No phone app is available. Select and copy the number instead.',
        );
      }
    } catch (_) {
      if (!mounted || !accountMatches) return;
      showMessage('Could not open a phone app. Copy the number instead.');
    } finally {
      if (mounted) {
        setState(() => openingPhone = false);
      }
    }
  }

  Future<void> shareTrip(String status, Map<String, dynamic>? data) async {
    if (!accountMatches) return;

    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);
    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    final driverName = readText(data, 'driverName');
    final driverPhone = readText(data, 'driverPhone');
    final registration = readText(data, 'driverRegistration');

    final assigned = [
      'Driver accepted',
      'Trip in progress',
      'Trip completed',
    ].contains(status);

    final details = [
      'TripLanka — Trip details',
      'Status: $status',
      'Pickup: ${booking.pickup}',
      if (booking.stops.isNotEmpty) 'Stops: ${booking.stops.join(' → ')}',
      'Destination: ${booking.destination}',
      'Departure / request time: $date at $time',
      'Vehicle: ${booking.vehicle}',
      'Passengers: ${booking.passengers}',
      if (assigned && driverName.isNotEmpty) 'Driver: $driverName',
      if (assigned && driverPhone.isNotEmpty) 'Driver phone: $driverPhone',
      if (assigned && registration.isNotEmpty)
        'Vehicle registration: $registration',
      if (booking.notes.isNotEmpty) 'Notes: ${booking.notes}',
      '',
      'Demo booking. This message does not include live location.',
    ].join('\n');

    try {
      await Clipboard.setData(ClipboardData(text: details));

      if (!mounted || !accountMatches) return;
      showMessage('Trip details copied. Paste them into your messaging app.');
    } catch (_) {
      if (!mounted || !accountMatches) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Trip details'),
          content: SingleChildScrollView(child: SelectableText(details)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void openSafety() {
    if (!accountMatches) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TravelSafetyScreen()));
  }

  String get vehicleAsset => switch (booking.vehicle) {
    'Tuk-tuk' => 'assets/vehicles/tuk_tuk.png',
    'Car' => 'assets/vehicles/car.png',
    'Van' => 'assets/vehicles/van.png',
    'Minibus' => 'assets/vehicles/minibus.png',
    _ => 'assets/vehicles/car.png',
  };

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

  Widget metric(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: blue, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget journeyDetails() {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);
    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'To ${booking.destination}',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pickup: ${booking.pickup}',
            style: const TextStyle(color: muted, height: 1.4),
          ),
          if (booking.stops.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Via ${booking.stops.join(' → ')}',
              style: const TextStyle(color: muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Departure / request time: $date at $time',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget tripPanel(
    String status,
    Map<String, dynamic>? data, {
    bool allowRetry = false,
  }) {
    final assigned = [
      'Driver accepted',
      'Trip in progress',
      'Trip completed',
    ].contains(status);

    final driverName = readText(data, 'driverName');
    final driverPhone = readText(data, 'driverPhone');
    final registration = readText(data, 'driverRegistration');
    final loadedRoute = route;

    final description = switch (status) {
      'Driver accepted' => 'Your driver has accepted this demo journey.',
      'Trip in progress' => 'Your driver has started the journey.',
      'Trip completed' => 'Your driver has marked the journey completed.',
      'Cancelled' => 'This trip has been cancelled.',
      'Waiting for driver' => 'Waiting for an approved driver to accept.',
      'Checking trip' => 'Loading your latest trip status.',
      'Saved journey' => 'Showing the saved route and journey details.',
      _ => 'Could not verify the latest trip status.',
    };

    final statusColor = switch (status) {
      'Driver accepted' => blue,
      'Trip in progress' => const Color(0xFFC48616),
      'Trip completed' => green,
      'Cancelled' => red,
      _ => navy,
    };

    return Column(
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
        Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(description, style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFEAF1FF),
              child: Icon(Icons.person_outline, color: blue, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assigned
                        ? driverName.isEmpty
                              ? 'Assigned driver'
                              : driverName
                        : 'Your journey',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${booking.vehicle} • '
                    '${booking.passengers} '
                    '${booking.passengers == 1 ? 'passenger' : 'passengers'}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  if (assigned && registration.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      registration,
                      style: const TextStyle(color: navy, fontSize: 12),
                    ),
                  ],
                  if (assigned && driverPhone.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    SelectableText(
                      driverPhone,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              vehicleAsset,
              width: 75,
              height: 55,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) =>
                  const Icon(Icons.directions_car, size: 48, color: blue),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !assigned || driverPhone.isEmpty || openingPhone
                    ? null
                    : () => callDriver(driverPhone),
                icon: const Icon(Icons.phone_outlined, size: 18),
                label: Text(openingPhone ? 'Opening...' : 'Call driver'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => shareTrip(status, data),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share trip'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: openSafety,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFEEF1),
              foregroundColor: red,
              elevation: 0,
            ),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Travel safety'),
          ),
        ),
        if (allowRetry)
          TextButton.icon(
            onPressed: retryRequest,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload trip status'),
          ),
        const SizedBox(height: 14),
        journeyDetails(),
        const SizedBox(height: 14),
        Row(
          children: [
            metric(
              loadedRoute == null
                  ? '—'
                  : '${loadedRoute.distanceKilometres.toStringAsFixed(1)} km',
              'Road distance',
              Icons.route,
            ),
            const SizedBox(width: 10),
            metric(
              loadedRoute == null
                  ? '—'
                  : formatDuration(loadedRoute.durationSeconds),
              'Estimated driving',
              Icons.schedule,
            ),
          ],
        ),
        if (routeError != null) ...[
          const SizedBox(height: 12),
          Text(routeError!, style: const TextStyle(color: red, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: calculating ? null : calculateRoute,
            icon: const Icon(Icons.route),
            label: Text(
              calculating
                  ? 'Finding road route...'
                  : routeError != null
                  ? 'Try route again'
                  : loadedRoute == null
                  ? 'Calculate route'
                  : 'Refresh route',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Demo journey. No live driver location or pickup arrival time. '
          'Call driver opens an available calling app. '
          'Share trip copies details for you to send.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 6),
        const Text(
          'Route calculation sends selected locations to the OSRM '
          'demo service. Driving estimates exclude live traffic, '
          'visits, waiting and separately scheduled return journeys.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  Widget assignmentContent() {
    if (!hasRequest) {
      return tripPanel('Saved journey', null);
    }

    if (requestStream == null) {
      return tripPanel('Trip status unavailable', null);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey('${widget.requestId}:$requestVersion'),
      stream: requestStream,
      builder: (context, snapshot) {
        if (!accountMatches) return const SizedBox.shrink();

        if (snapshot.hasError) {
          return tripPanel('Trip status unavailable', null, allowRetry: true);
        }

        if (!snapshot.hasData) {
          return tripPanel('Checking trip', null);
        }

        final data = snapshot.data!.data();

        if (data == null ||
            (data['ownerId'] != accountId && data['driverId'] != accountId)) {
          return tripPanel('Trip status unavailable', null, allowRetry: true);
        }

        final status = switch (readText(data, 'status')) {
          'pending' => 'Waiting for driver',
          'accepted' => 'Driver accepted',
          'in_progress' => 'Trip in progress',
          'completed' => 'Trip completed',
          'cancelled' => 'Cancelled',
          _ => 'Trip status unavailable',
        };

        return tripPanel(
          status,
          data,
          allowRetry: status == 'Trip status unavailable',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!accountMatches) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your trip')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your account changed. Return to your bookings '
              'and reopen this trip.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!validCoordinates(booking.pickupCoordinates) ||
        !validCoordinates(booking.destinationCoordinates)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your trip')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This booking needs pickup and destination map locations. '
              'Create a booking using Search pickup and Search destination.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final points = savedPoints;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    ColoredBox(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back, color: navy),
                            ),
                            const Expanded(
                              child: Text(
                                'Your trip',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Travel safety',
                              onPressed: openSafety,
                              icon: const Icon(
                                Icons.health_and_safety_outlined,
                                color: blue,
                              ),
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
                            if (widget.loadMapTiles) calculateRoute();
                          },
                        ),
                        children: [
                          if (widget.loadMapTiles)
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.sevi2001.triplanka',
                            ),
                          if (loadedRoute != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: loadedRoute.points,
                                  color: blue,
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
                                if (validCoordinates(
                                  booking.stopCoordinates[i],
                                ))
                                  locationMarker(
                                    point: mapPoint(
                                      booking.stopCoordinates[i]!,
                                    ),
                                    color: blue,
                                    label: booking.stops[i],
                                    number: '${i + 1}',
                                  ),
                              if (!sameEndpoints)
                                locationMarker(
                                  point: destination,
                                  color: red,
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
                        maxHeight: constraints.maxHeight * 0.52,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: assignmentContent(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
