import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'booking_store.dart';
import 'cloud_booking_store.dart';
import 'split_cost_screen.dart';
import 'trip_map_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  StreamSubscription<User?>? authSubscription;
  Stream<List<CloudBookingEntry>>? bookingStream;
  String? userId;
  int streamVersion = 0;

  @override
  void initState() {
    super.initState();
    setAccount(FirebaseAuth.instance.currentUser);

    authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == userId) return;

      setState(() {
        setAccount(user);
      });
    });
  }

  void setAccount(User? user) {
    userId = user?.uid;
    bookingStream = user == null
        ? null
        : CloudBookingStore.watchEntries(user.uid);
    streamVersion++;
  }

  void retry() {
    setState(() {
      setAccount(FirebaseAuth.instance.currentUser);
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  Widget statusMessage(String text, {bool retryAllowed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 60,
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          if (retryAllowed) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: retry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }

  String errorMessage(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Access denied. Check your Firestore booking rules.';
    }

    return 'Could not load your bookings. '
        'Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'My bookings',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Demo bookings saved to your account.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (userId == null)
                statusMessage('Sign in to view your bookings.')
              else
                StreamBuilder<List<CloudBookingEntry>>(
                  key: ValueKey('$userId:$streamVersion'),
                  stream: bookingStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return statusMessage(
                        errorMessage(snapshot.error),
                        retryAllowed: true,
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final entries = snapshot.data!;

                    if (entries.isEmpty) {
                      return statusMessage(
                        'No online bookings yet.\n'
                        'Create and confirm a trip from Home.\n\n'
                        'Earlier local bookings are not '
                        'uploaded automatically.',
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in entries)
                          BookingCard(key: ValueKey(entry.id), entry: entry),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingCard extends StatefulWidget {
  const BookingCard({super.key, required this.entry});

  final CloudBookingEntry entry;

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  bool cancelling = false;

  TripBooking get booking => widget.entry.booking;

  Future<void> cancelBooking() async {
    if (cancelling || widget.entry.cancelled) return;

    // Capture the exact booking being confirmed.
    final entry = widget.entry;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel demo booking?'),
        content: Text(
          '${entry.booking.pickup} → ${entry.booking.destination}\n\n'
          'This booking will remain in your account '
          'with a cancelled label.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true || cancelling || widget.entry.cancelled) {
      return;
    }

    setState(() {
      cancelling = true;
    });

    try {
      await CloudBookingStore.cancel(entry);

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != entry.userId) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Demo booking cancelled.')));
    } catch (error) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != entry.userId) {
        return;
      }

      debugPrint('Booking cancellation failed: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          cancelling = false;
        });
      }
    }
  }

  Future<void> shareTripDetails() async {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);
    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    final details = [
      'TripLanka — Trip details',
      '',
      'Status: ${widget.entry.cancelled ? 'Cancelled' : 'Demo booking saved'}',
      'Pickup: ${booking.pickup}',
      'Destination: ${booking.destination}',
      if (booking.stops.isNotEmpty) 'Stops: ${booking.stops.join(' → ')}',
      'Departure / request time: $date at $time',
      'Vehicle: ${booking.vehicle}',
      'Passengers: ${booking.passengers}',
      if (booking.notes.isNotEmpty) 'Notes: ${booking.notes}',
      '',
      'Demo only. No driver has been assigned.',
      'This message does not include live location.',
    ].join('\n');

    try {
      await Clipboard.setData(ClipboardData(text: details));

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Trip details copied. Paste them into your messaging app.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

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

  bool validCoordinates(TripCoordinates? point) {
    return point != null &&
        point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);
    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    final cancelled = widget.entry.cancelled;
    final hasMapLocations =
        validCoordinates(booking.pickupCoordinates) &&
        validCoordinates(booking.destinationCoordinates);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  cancelled ? Icons.cancel_outlined : Icons.route,
                  color: cancelled ? Colors.red : Colors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cancelled
                        ? 'Demo booking cancelled'
                        : 'Demo booking saved to your account',
                    style: TextStyle(
                      color: cancelled ? Colors.red : Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${booking.pickup} → ${booking.destination}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            if (booking.stops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Stops: ${booking.stops.join(' → ')}'),
            ],
            const SizedBox(height: 12),
            Text('Departure / request time: $date at $time'),
            const SizedBox(height: 8),
            Text('Vehicle: ${booking.vehicle}'),
            const SizedBox(height: 8),
            Text('Passengers: ${booking.passengers}'),
            if (booking.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Additional details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(booking.notes),
            ],
            const SizedBox(height: 12),
            const Text(
              'Demo only. No driver has been assigned.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (hasMapLocations)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TripMapScreen(booking: booking),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('View trip map'),
              )
            else
              const Text(
                'Map unavailable: both map locations are required.',
                style: TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SplitCostScreen(passengers: booking.passengers),
                  ),
                );
              },
              icon: const Icon(Icons.groups),
              label: const Text('Split the cost'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: shareTripDetails,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share trip details'),
            ),
            if (!cancelled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: cancelling ? null : cancelBooking,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(
                  cancelling ? 'Cancelling...' : 'Cancel demo booking',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
