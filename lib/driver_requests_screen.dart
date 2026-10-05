import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'trip_request_store.dart';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);

  late final String? userId;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? driverStream;
  Stream<List<TripRequestEntry>>? requestStream;

  String? streamVehicle;
  String? acceptingId;

  @override
  void initState() {
    super.initState();

    userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      driverStream = FirebaseFirestore.instance
          .collection('drivers')
          .doc(userId)
          .snapshots();
    }
  }

  void retry() {
    setState(() {
      requestStream = null;
      streamVehicle = null;

      if (userId != null) {
        driverStream = FirebaseFirestore.instance
            .collection('drivers')
            .doc(userId)
            .snapshots();
      }
    });
  }

  Future<void> acceptTrip(TripRequestEntry entry) async {
    if (acceptingId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept this demo trip?'),
        content: Text(
          '${entry.booking.pickup} → ${entry.booking.destination}\n\n'
          'Your saved driver name, phone number, and vehicle '
          'registration will be attached to this request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Accept trip'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || acceptingId != null) return;
    if (FirebaseAuth.instance.currentUser?.uid != userId) return;

    setState(() => acceptingId = entry.id);

    try {
      await TripRequestStore.accept(entry.id);

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != userId) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Demo trip accepted.')));
    } catch (error) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != userId) return;

      final message = error is StateError
          ? error.message
          : 'Could not accept this trip. Refresh and try again.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => acceptingId = null);
      }
    }
  }

  Widget message(String text, {bool retryAllowed = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, color: blue, size: 44),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.5),
          ),
          if (retryAllowed) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: retry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }

  Widget requestCard(TripRequestEntry entry) {
    final trip = entry.booking;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(trip.departure);
    final time = TimeOfDay.fromDateTime(trip.departure).format(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.vehicle,
            style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '${trip.pickup} → ${trip.destination}',
            style: const TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trip.stops.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Stops: ${trip.stops.join(' → ')}'),
          ],
          const SizedBox(height: 12),
          Text('Departure / request time: $date at $time'),
          const SizedBox(height: 6),
          Text('Passengers: ${trip.passengers}'),
          if (trip.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(trip.notes, style: const TextStyle(color: muted, height: 1.4)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: acceptingId != null ? null : () => acceptTrip(entry),
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                acceptingId == entry.id ? 'Accepting...' : 'Accept trip',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget content() {
    if (userId == null) {
      return message('Sign in to view trip requests.');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: driverStream,
      builder: (context, driverSnapshot) {
        if (FirebaseAuth.instance.currentUser?.uid != userId) {
          return message('Your account changed. Reopen this screen.');
        }

        if (driverSnapshot.hasError) {
          return message(
            'Could not load your driver profile.',
            retryAllowed: true,
          );
        }

        if (!driverSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final driver = driverSnapshot.data!.data();

        if (driver == null || driver['status'] != 'approved') {
          return message('An approved driver profile is required.');
        }

        final vehicle = driver['vehicleType'];
        final capacity = driver['passengerCapacity'];

        if (vehicle is! String || capacity is! int) {
          return message('Your driver vehicle details are incomplete.');
        }

        if (requestStream == null || streamVehicle != vehicle) {
          streamVehicle = vehicle;
          requestStream = TripRequestStore.watchAvailable(vehicle);
        }

        return StreamBuilder<List<TripRequestEntry>>(
          key: ValueKey(vehicle),
          stream: requestStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return message(
                'Could not load requests. Check your connection '
                'and published trip-request rules.',
                retryAllowed: true,
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final entries = snapshot.data!
                .where(
                  (entry) =>
                      entry.ownerId != userId &&
                      entry.booking.passengers <= capacity,
                )
                .toList();

            if (entries.isEmpty) {
              return message(
                'No available requests fit your vehicle.\n\n'
                'Create a new trip using a separate passenger account.',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Available demo trips',
                  style: TextStyle(
                    color: navy,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check the journey and departure time before accepting. '
                  'Fares and live driver tracking are not connected.',
                  style: TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                for (final entry in entries) requestCard(entry),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Trip requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: content(),
          ),
        ),
      ),
    );
  }
}
