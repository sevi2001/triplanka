import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'booking_store.dart';
import 'trip_map_screen.dart';
import 'trip_request_store.dart';

class DriverAssignedTripsScreen extends StatefulWidget {
  const DriverAssignedTripsScreen({super.key});
  @override
  State<DriverAssignedTripsScreen> createState() =>
      _DriverAssignedTripsScreenState();
}

class _DriverAssignedTripsScreenState extends State<DriverAssignedTripsScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);
  static const green = Color(0xFF159A75);
  static const red = Color(0xFFD94D64);
  StreamSubscription<User?>? authSubscription;
  Stream<List<TripRequestEntry>>? tripsStream;
  String? userId;
  String selectedFilter = 'All';
  int streamVersion = 0;
  final Set<String> busyTrips = {};
  final Set<String> confirmingTrips = {};
  @override
  void initState() {
    super.initState();
    setAccount(FirebaseAuth.instance.currentUser);
    authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == userId) return;
      setState(() {
        selectedFilter = 'All';
        setAccount(user);
      });
    });
  }

  void setAccount(User? user) {
    userId = user?.uid;
    streamVersion++;
    tripsStream = user == null
        ? null
        : TripRequestStore.watchAssigned(user.uid);
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

  bool validCoordinates(TripCoordinates? point) {
    return point != null &&
        point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  void openMap(TripRequestEntry entry) {
    if (userId == null ||
        FirebaseAuth.instance.currentUser?.uid != userId ||
        entry.driverId != userId) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TripMapScreen(booking: entry.booking, requestId: entry.id),
      ),
    );
  }

  Future<void> updateTrip(TripRequestEntry entry) async {
    final accountId = userId;
    if (accountId == null ||
        FirebaseAuth.instance.currentUser?.uid != accountId ||
        entry.driverId != accountId ||
        busyTrips.contains(entry.id) ||
        confirmingTrips.contains(entry.id)) {
      return;
    }
    if (!entry.accepted && !entry.inProgress) return;
    final starting = entry.accepted;
    confirmingTrips.add(entry.id);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(starting ? 'Start this trip?' : 'Complete this trip?'),
          content: Text(
            starting
                ? 'Confirm that the journey is starting.\n\n'
                      '${entry.booking.pickup} → '
                      '${entry.booking.destination}'
                : 'Confirm that the journey has finished.\n\n'
                      'Once completed, this trip cannot be restarted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(starting ? 'Start trip' : 'Complete trip'),
            ),
          ],
        ),
      );
    } finally {
      confirmingTrips.remove(entry.id);
    }
    if (!mounted ||
        confirmed != true ||
        userId != accountId ||
        FirebaseAuth.instance.currentUser?.uid != accountId) {
      return;
    }
    setState(() {
      busyTrips.add(entry.id);
    });
    try {
      if (starting) {
        await TripRequestStore.start(entry.id);
      } else {
        await TripRequestStore.complete(entry.id);
      }
      if (!mounted ||
          userId != accountId ||
          FirebaseAuth.instance.currentUser?.uid != accountId) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(starting ? 'Trip started.' : 'Trip completed.'),
          ),
        );
    } catch (error) {
      if (!mounted ||
          userId != accountId ||
          FirebaseAuth.instance.currentUser?.uid != accountId) {
        return;
      }
      final message = error is StateError
          ? error.message.toString()
          : 'Could not update the trip. Check your connection '
                'and permissions, then try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          busyTrips.remove(entry.id);
        });
      }
    }
  }

  Widget messageCard({
    required String title,
    required String message,
    bool allowRetry = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.route_outlined, color: blue, size: 46),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.5),
          ),
          if (allowRetry) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget locationRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: blue, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: navy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget ratingPanel(TripRequestEntry entry) {
    final stars = entry.ratingStars;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE7AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Passenger feedback',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (stars == null) ...[
            const Text(
              'Not rated yet',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'The passenger can rate this completed trip. '
              'Their feedback will appear here after submission.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ] else ...[
            Semantics(
              label: 'Passenger rating: $stars out of 5 stars',
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (int index = 1; index <= 5; index++)
                      Icon(
                        index <= stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFC48616),
                        size: 25,
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '$stars/5',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              entry.ratingComment.isEmpty
                  ? 'The passenger did not add a written review.'
                  : entry.ratingComment,
              style: const TextStyle(color: navy, fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget tripCard(TripRequestEntry entry) {
    final trip = entry.booking;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(trip.departure);
    final time = TimeOfDay.fromDateTime(trip.departure).format(context);
    final statusColor = switch (entry.status) {
      'accepted' => blue,
      'in_progress' => const Color(0xFFC48616),
      'completed' => green,
      'cancelled' => red,
      _ => muted,
    };
    final statusMessage = switch (entry.status) {
      'accepted' => 'Start the trip when the journey begins.',
      'in_progress' => 'Complete the trip when the journey finishes.',
      'completed' => 'This journey has been completed.',
      'cancelled' => 'The passenger cancelled this trip.',
      _ => 'Refresh the page to check this trip’s status.',
    };
    final hasMapLocations =
        validCoordinates(trip.pickupCoordinates) &&
        validCoordinates(trip.destinationCoordinates);
    final busy = busyTrips.contains(entry.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, color: blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trip.vehicle,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              entry.statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          locationRow(
            label: 'Pickup',
            value: trip.pickup,
            icon: Icons.my_location,
            color: blue,
          ),
          for (int i = 0; i < trip.stops.length; i++)
            locationRow(
              label: 'Stop ${i + 1}',
              value: trip.stops[i],
              icon: Icons.location_on_outlined,
              color: muted,
            ),
          locationRow(
            label: 'Destination',
            value: trip.destination,
            icon: Icons.location_on_outlined,
            color: red,
          ),
          const SizedBox(height: 14),
          const Text(
            'Departure / request time',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              detailChip(Icons.calendar_today_outlined, date),
              detailChip(Icons.access_time, time),
              detailChip(
                Icons.people_outline,
                '${trip.passengers} '
                '${trip.passengers == 1 ? 'passenger' : 'passengers'}',
              ),
            ],
          ),
          if (trip.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                leading: const Icon(Icons.notes_outlined, color: blue),
                title: const Text(
                  'Additional details',
                  style: TextStyle(
                    color: navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      trip.notes,
                      style: const TextStyle(color: muted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            statusMessage,
            style: TextStyle(
              color: entry.cancelled ? red : muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (entry.completed) ...[
            const SizedBox(height: 16),
            ratingPanel(entry),
          ],
          if (entry.accepted || entry.inProgress) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : () => updateTrip(entry),
                style: FilledButton.styleFrom(
                  backgroundColor: entry.inProgress ? green : blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        entry.accepted
                            ? Icons.play_arrow
                            : Icons.check_circle_outline,
                      ),
                label: Text(
                  busy
                      ? 'Updating...'
                      : entry.accepted
                      ? 'Start trip'
                      : 'Complete trip',
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (hasMapLocations)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => openMap(entry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View trip map'),
              ),
            )
          else
            const Text(
              'Map unavailable: this trip has no valid saved '
              'pickup and destination coordinates.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
        ],
      ),
    );
  }

  Widget tripsContent() {
    if (userId == null) {
      return messageCard(
        title: 'Sign in first',
        message: 'Sign in with your driver account to view your trips.',
      );
    }
    return StreamBuilder<List<TripRequestEntry>>(
      key: ValueKey('$userId:$streamVersion'),
      stream: tripsStream,
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser?.uid != userId) {
          return messageCard(
            title: 'Account changed',
            message: 'Refresh the page to continue.',
            allowRetry: true,
          );
        }
        if (snapshot.hasError) {
          return messageCard(
            title: 'Could not load your trips',
            message:
                'Check your connection and Firestore permissions, '
                'then try again.',
            allowRetry: true,
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: blue)),
          );
        }
        final allEntries = snapshot.data!
            .where((entry) => entry.driverId == userId)
            .toList();
        final entries = allEntries.where((entry) {
          return switch (selectedFilter) {
            'Accepted' => entry.accepted,
            'In progress' => entry.inProgress,
            'Completed' => entry.completed,
            'Cancelled' => entry.cancelled,
            _ => true,
          };
        }).toList();
        if (entries.isEmpty) {
          return messageCard(
            title: allEntries.isEmpty
                ? 'No assigned trips yet'
                : 'No ${selectedFilter.toLowerCase()} trips',
            message: allEntries.isEmpty
                ? 'Return to Driver dashboard and accept '
                      'a matching available request.'
                : 'Choose another filter to view your trips.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${entries.length} '
                '${entries.length == 1 ? 'trip' : 'trips'}',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
            ),
            for (final entry in entries)
              KeyedSubtree(key: ValueKey(entry.id), child: tripCard(entry)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('My trips'),
        backgroundColor: background,
        foregroundColor: navy,
        actions: [
          IconButton(
            tooltip: 'Refresh trips',
            onPressed: retry,
            icon: const Icon(Icons.refresh, color: blue),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [blue, Color(0xFF1547B8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.route_outlined, color: Colors.white, size: 36),
                      SizedBox(height: 14),
                      Text(
                        'Your journeys',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start accepted trips and mark '
                        'finished journeys as completed.',
                        style: TextStyle(color: Color(0xFFDCE8FF), height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in [
                      'All',
                      'Accepted',
                      'In progress',
                      'Completed',
                      'Cancelled',
                    ])
                      ChoiceChip(
                        label: Text(filter),
                        selected: selectedFilter == filter,
                        showCheckmark: false,
                        backgroundColor: Colors.white,
                        selectedColor: blue,
                        labelStyle: TextStyle(
                          color: selectedFilter == filter
                              ? Colors.white
                              : muted,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: selectedFilter == filter ? blue : borderColor,
                        ),
                        onSelected: (_) {
                          setState(() => selectedFilter = filter);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                tripsContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
