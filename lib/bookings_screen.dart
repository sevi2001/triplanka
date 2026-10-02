import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'booking_store.dart';
import 'split_cost_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ValueListenableBuilder<List<TripBooking>>(
            valueListenable: BookingStore.bookings,
            builder: (context, bookings, _) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'My bookings',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Demo bookings saved on this device.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  if (bookings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 64,
                            color: Colors.teal,
                          ),
                          SizedBox(height: 16),
                          Text('No bookings yet'),
                          SizedBox(height: 8),
                          Text('Plan a trip from the Home tab.'),
                        ],
                      ),
                    ),
                  for (final booking in bookings) BookingCard(booking: booking),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});

  final TripBooking booking;

  Future<void> shareTripDetails(BuildContext context) async {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);

    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    final details = [
      'TripLanka — Trip details',
      '',
      'Pickup: ${booking.pickup}',
      'Destination: ${booking.destination}',
      if (booking.stops.isNotEmpty) 'Stops: ${booking.stops.join(' → ')}',
      'Departure / request time: $date at $time',
      'Vehicle type: ${booking.vehicle}',
      'Passengers: ${booking.passengers}',
      if (booking.notes.isNotEmpty) ...[
        '',
        'Additional details:',
        booking.notes,
      ],
      '',
      'Demo booking. No driver has been assigned.',
      'This message does not include live location.',
    ].join('\n');

    try {
      await Clipboard.setData(ClipboardData(text: details));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Trip details copied. '
              'Paste them into your messaging app.',
            ),
          ),
        );
    } catch (_) {
      if (!context.mounted) return;

      showDialog<void>(
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

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);

    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.route, color: Colors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo booking saved',
                    style: TextStyle(
                      color: Colors.teal,
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.notes, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Additional details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(booking.notes),
            ],
            const SizedBox(height: 12),
            const Text(
              'No driver has been assigned.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
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
              onPressed: () => shareTripDetails(context),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share trip details'),
            ),
          ],
        ),
      ),
    );
  }
}
