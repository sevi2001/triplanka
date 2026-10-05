import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_store.dart';
import 'cloud_booking_store.dart';
import 'split_cost_screen.dart';
import 'travel_safety_screen.dart';
import 'trip_map_screen.dart';

const _blue = Color(0xFF2563EB);
const _navy = Color(0xFF14213D);
const _muted = Color(0xFF738097);
const _background = Color(0xFFF5F7FB);
const _border = Color(0xFFE5EAF2);
const _red = Color(0xFFD94D64);
const _green = Color(0xFF159A75);
const _amber = Color(0xFFC48616);

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
  String selectedFilter = 'All';

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

  Widget statusMessage({
    required String title,
    required String message,
    bool retryAllowed = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_month_outlined, color: _blue, size: 44),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.5),
          ),
          if (retryAllowed) ...[
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

  Widget bookingContent() {
    if (userId == null) {
      return statusMessage(
        title: 'Sign in to view bookings',
        message: 'Your saved trips will appear here.',
      );
    }

    return StreamBuilder<List<CloudBookingEntry>>(
      key: ValueKey('$userId:$streamVersion'),
      stream: bookingStream,
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser?.uid != userId) {
          return statusMessage(
            title: 'Account changed',
            message: 'Refresh your bookings to continue.',
            retryAllowed: true,
          );
        }

        if (snapshot.hasError) {
          return statusMessage(
            title: 'Could not load bookings',
            message:
                'Check your connection and account permissions, '
                'then try again.',
            retryAllowed: true,
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(color: _blue)),
          );
        }

        final allEntries = snapshot.data!;
        final entries = allEntries.where((entry) {
          return switch (selectedFilter) {
            'Upcoming' => entry.upcoming,
            'In progress' => entry.inProgress,
            'Completed' => entry.completed,
            'Cancelled' => entry.cancelled,
            _ => true,
          };
        }).toList();

        if (entries.isEmpty) {
          return statusMessage(
            title: allEntries.isEmpty
                ? 'Your next journey starts here'
                : 'No ${selectedFilter.toLowerCase()} bookings',
            message: allEntries.isEmpty
                ? 'Create and confirm a trip from Home.\n\n'
                      'Earlier bookings saved only on your device '
                      'are not uploaded automatically.'
                : 'Choose another filter or create a new trip.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${entries.length} '
                '${entries.length == 1 ? 'booking' : 'bookings'}',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ),
            for (final entry in entries)
              BookingCard(
                key: ValueKey('${entry.userId}:${entry.id}'),
                entry: entry,
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: _background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'My bookings',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your journeys, all in one place.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in [
                      'All',
                      'Upcoming',
                      'In progress',
                      'Completed',
                      'Cancelled',
                    ])
                      ChoiceChip(
                        label: Text(filter),
                        selected: selectedFilter == filter,
                        showCheckmark: false,
                        backgroundColor: Colors.white,
                        selectedColor: _blue,
                        labelStyle: TextStyle(
                          color: selectedFilter == filter
                              ? Colors.white
                              : _muted,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: selectedFilter == filter ? _blue : _border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (_) {
                          setState(() => selectedFilter = filter);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upcoming includes trips waiting for a driver, accepted trips, '
                  'and earlier bookings without a driver request. '
                  'Started and completed journeys appear in their own tabs.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 22),
                bookingContent(),
              ],
            ),
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
  Stream<DocumentSnapshot<Map<String, dynamic>>>? requestStream;
  int requestVersion = 0;

  bool cancelling = false;
  bool confirmingCancellation = false;
  bool openingPhone = false;

  TripBooking get booking => widget.entry.booking;

  bool get sameAccount =>
      FirebaseAuth.instance.currentUser?.uid == widget.entry.userId;

  @override
  void initState() {
    super.initState();
    prepareRequest();
  }

  @override
  void didUpdateWidget(covariant BookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry.requestId != widget.entry.requestId ||
        oldWidget.entry.userId != widget.entry.userId) {
      prepareRequest();
    }
  }

  void prepareRequest() {
    final requestId = widget.entry.requestId?.trim();
    requestVersion++;

    requestStream = requestId == null || requestId.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('tripRequests')
              .doc(requestId)
              .snapshots();
  }

  void retryRequest() {
    setState(prepareRequest);
  }

  String readText(Map<String, dynamic>? data, String key) {
    final value = data?[key];
    return value is String ? value.trim() : '';
  }

  bool hasAssignedDriver(String status) {
    return status == 'Driver accepted' ||
        status == 'Trip in progress' ||
        status == 'Trip completed';
  }

  bool canCancelStatus(String status) {
    return !widget.entry.cancelled &&
        (status == 'Waiting for driver' ||
            status == 'Driver accepted' ||
            status == 'Earlier booking');
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

  void showMessage(String message) {
    if (!mounted || !sameAccount) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openPhoneApp(String phone) async {
    if (!sameAccount || openingPhone || widget.entry.cancelled) return;

    final number = phone.trim().replaceAll(RegExp(r'[\s()-]'), '');

    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(number)) {
      showMessage('The driver phone number is unavailable or invalid.');
      return;
    }

    setState(() => openingPhone = true);

    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: number));

      if (!mounted || !sameAccount) return;

      if (!opened) {
        showMessage(
          'No phone app is available. Select and copy the number instead.',
        );
      }
    } catch (_) {
      if (!mounted || !sameAccount) return;

      showMessage(
        'Could not open a phone app. Select and copy the number instead.',
      );
    } finally {
      if (mounted) {
        setState(() => openingPhone = false);
      }
    }
  }

  Future<void> cancelBooking(String assignmentStatus) async {
    if (!sameAccount ||
        cancelling ||
        confirmingCancellation ||
        !canCancelStatus(assignmentStatus)) {
      return;
    }

    final entry = widget.entry;
    confirmingCancellation = true;
    bool? confirmed;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel demo booking?'),
          content: Text(
            '${entry.booking.pickup} → ${entry.booking.destination}\n\n'
            'The booking will remain in your account '
            'with a cancelled label.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel booking'),
            ),
          ],
        ),
      );
    } finally {
      confirmingCancellation = false;
    }

    if (!mounted ||
        !sameAccount ||
        confirmed != true ||
        cancelling ||
        widget.entry.cancelled) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => cancelling = true);

    try {
      // The store transaction and Firestore rules check the latest status.
      await CloudBookingStore.cancel(entry);

      if (FirebaseAuth.instance.currentUser?.uid != entry.userId) return;

      if (messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Demo booking cancelled.')),
          );
      }
    } catch (error) {
      debugPrint('Booking cancellation failed: $error');

      if (FirebaseAuth.instance.currentUser?.uid != entry.userId) return;

      final message = error is StateError
          ? error.message.toString()
          : 'Could not cancel. The trip may have started, '
                'or your connection may be unavailable.';

      if (messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => cancelling = false);
      }
    }
  }

  Future<void> shareTripDetails({
    required String assignmentStatus,
    Map<String, dynamic>? requestData,
  }) async {
    if (!sameAccount) return;

    final entry = widget.entry;
    final trip = entry.booking;
    final cancelled = entry.cancelled || assignmentStatus == 'Cancelled';

    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(trip.departure);
    final time = TimeOfDay.fromDateTime(trip.departure).format(context);

    final driverName = readText(requestData, 'driverName');
    final driverPhone = readText(requestData, 'driverPhone');
    final registration = readText(requestData, 'driverRegistration');

    final details = [
      'TripLanka — Trip details',
      '',
      'Status: ${cancelled ? 'Cancelled' : assignmentStatus}',
      'Pickup: ${trip.pickup}',
      'Destination: ${trip.destination}',
      if (trip.stops.isNotEmpty) 'Stops: ${trip.stops.join(' → ')}',
      'Departure / request time: $date at $time',
      'Vehicle: ${trip.vehicle}',
      'Passengers: ${trip.passengers}',
      if (!cancelled && hasAssignedDriver(assignmentStatus)) ...[
        '',
        if (driverName.isNotEmpty) 'Driver: $driverName',
        if (driverPhone.isNotEmpty) 'Driver phone: $driverPhone',
        if (registration.isNotEmpty) 'Vehicle registration: $registration',
      ],
      if (trip.notes.isNotEmpty) 'Notes: ${trip.notes}',
      '',
      'Demo booking.',
      'This message does not include live location.',
    ].join('\n');

    try {
      await Clipboard.setData(ClipboardData(text: details));

      if (!mounted || !sameAccount) return;

      showMessage('Trip details copied. Paste them into your messaging app.');
    } catch (_) {
      if (!mounted || !sameAccount) return;

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

  void openMap() {
    if (!sameAccount) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TripMapScreen(booking: booking, requestId: widget.entry.requestId),
      ),
    );
  }

  void openSplitCost() {
    if (!sameAccount) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SplitCostScreen(passengers: booking.passengers),
      ),
    );
  }

  void openSafety() {
    if (!sameAccount) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TravelSafetyScreen()));
  }

  Widget informationRow({
    required String label,
    required String value,
    required IconData icon,
    Color color = _blue,
    bool selectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                if (selectable)
                  SelectableText(
                    value,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    value,
                    style: const TextStyle(
                      color: _navy,
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

  Widget detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _blue, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: _navy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget assignmentPanel(
    String status,
    Map<String, dynamic>? data, {
    bool allowRetry = false,
  }) {
    final assigned = hasAssignedDriver(status);
    final inProgress = status == 'Trip in progress';

    final color = switch (status) {
      'Driver accepted' => _green,
      'Trip in progress' => _amber,
      'Trip completed' => _green,
      'Cancelled' => _red,
      _ => _muted,
    };

    final message = switch (status) {
      'Driver accepted' => 'A driver has accepted this demo request.',
      'Trip in progress' => 'Your driver has started this journey.',
      'Trip completed' => 'Your driver has marked this journey as completed.',
      'Waiting for driver' =>
        'Your request is available to matching approved drivers.',
      'Cancelled' => 'This booking has been cancelled.',
      'Checking driver' => 'Loading the latest trip status.',
      'Earlier booking' =>
        'This earlier booking was not posted as a driver request.',
      'Request unavailable' => 'The linked request could not be found.',
      _ => 'Could not verify the trip status. Please try again.',
    };

    final panelColor = inProgress
        ? const Color(0xFFFFF8EB)
        : assigned
        ? const Color(0xFFEEF9F5)
        : _background;

    final driverName = readText(data, 'driverName');
    final driverPhone = readText(data, 'driverPhone');
    final registration = readText(data, 'driverRegistration');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                inProgress
                    ? Icons.directions_car_outlined
                    : assigned
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: color,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          if (assigned) ...[
            const SizedBox(height: 10),
            informationRow(
              label: 'Driver name',
              value: driverName.isEmpty ? 'Not provided' : driverName,
              icon: Icons.person_outline,
            ),
            informationRow(
              label: 'Driver phone',
              value: driverPhone.isEmpty ? 'Not provided' : driverPhone,
              icon: Icons.phone_outlined,
              selectable: true,
            ),
            informationRow(
              label: 'Vehicle registration',
              value: registration.isEmpty ? 'Not provided' : registration,
              icon: Icons.badge_outlined,
            ),
            if (driverPhone.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: openingPhone
                      ? null
                      : () => openPhoneApp(driverPhone),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.phone_outlined),
                  label: Text(openingPhone ? 'Opening...' : 'Open phone app'),
                ),
              ),
            ],
          ],
          if (allowRetry) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: retryRequest,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCard(
    String assignmentStatus,
    Map<String, dynamic>? requestData, {
    bool allowRetry = false,
  }) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);
    final time = TimeOfDay.fromDateTime(booking.departure).format(context);

    final cancelled = widget.entry.cancelled || assignmentStatus == 'Cancelled';
    final accepted = assignmentStatus == 'Driver accepted';
    final inProgress = assignmentStatus == 'Trip in progress';
    final completed = assignmentStatus == 'Trip completed';

    final statusColor = cancelled
        ? _red
        : inProgress
        ? _amber
        : accepted || completed
        ? _green
        : _blue;

    final badgeLabel = cancelled
        ? 'Cancelled'
        : completed
        ? 'Completed'
        : inProgress
        ? 'In progress'
        : accepted
        ? 'Accepted'
        : 'Active demo';

    final hasMapLocations =
        validCoordinates(booking.pickupCoordinates) &&
        validCoordinates(booking.destinationCoordinates);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, color: _blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  booking.vehicle,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          informationRow(
            label: 'Pickup',
            value: booking.pickup,
            icon: Icons.my_location,
          ),
          for (int i = 0; i < booking.stops.length; i++)
            informationRow(
              label: 'Stop ${i + 1}',
              value: booking.stops[i],
              icon: Icons.location_on_outlined,
              color: _muted,
            ),
          informationRow(
            label: 'Destination',
            value: booking.destination,
            icon: Icons.location_on_outlined,
            color: _red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Departure / request time',
            style: TextStyle(color: _muted, fontSize: 11),
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
                '${booking.passengers} '
                '${booking.passengers == 1 ? 'passenger' : 'passengers'}',
              ),
            ],
          ),
          if (booking.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                leading: const Icon(Icons.notes_outlined, color: _blue),
                title: const Text(
                  'Additional details',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      booking.notes,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          assignmentPanel(
            cancelled ? 'Cancelled' : assignmentStatus,
            requestData,
            allowRetry: !cancelled && allowRetry,
          ),
          const SizedBox(height: 16),
          if (hasMapLocations)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: openMap,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
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
              'Map unavailable: select pickup and destination '
              'on the map when creating a trip.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              actionButton(
                label: 'Split the cost',
                icon: Icons.groups_outlined,
                onPressed: openSplitCost,
              ),
              actionButton(
                label: 'Share trip details',
                icon: Icons.share_outlined,
                onPressed: () => shareTripDetails(
                  assignmentStatus: assignmentStatus,
                  requestData: requestData,
                ),
              ),
              actionButton(
                label: 'Travel safety',
                icon: Icons.health_and_safety_outlined,
                onPressed: openSafety,
              ),
            ],
          ),
          if (!cancelled && canCancelStatus(assignmentStatus)) ...[
            const SizedBox(height: 8),
            const Divider(color: _border),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: cancelling
                    ? null
                    : () => cancelBooking(assignmentStatus),
                style: TextButton.styleFrom(foregroundColor: _red),
                icon: cancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _red,
                        ),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(
                  cancelling ? 'Cancelling...' : 'Cancel demo booking',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!sameAccount) return const SizedBox.shrink();

    if (widget.entry.cancelled) {
      return buildCard('Cancelled', null);
    }

    if (requestStream == null) {
      return buildCard('Earlier booking', null);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(
        '${widget.entry.userId}:'
        '${widget.entry.requestId}:$requestVersion',
      ),
      stream: requestStream,
      builder: (context, snapshot) {
        if (!sameAccount) return const SizedBox.shrink();

        if (snapshot.hasError) {
          return buildCard('Assignment unavailable', null, allowRetry: true);
        }

        if (!snapshot.hasData) {
          return buildCard('Checking driver', null);
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return buildCard('Request unavailable', null, allowRetry: true);
        }

        if (data['ownerId'] != widget.entry.userId ||
            data['bookingId'] != widget.entry.id) {
          return buildCard('Assignment unavailable', null, allowRetry: true);
        }

        return switch (readText(data, 'status')) {
          'pending' => buildCard('Waiting for driver', data),
          'accepted' => buildCard('Driver accepted', data),
          'in_progress' => buildCard('Trip in progress', data),
          'completed' => buildCard('Trip completed', data),
          'cancelled' => buildCard('Cancelled', null),
          _ => buildCard('Assignment unavailable', null, allowRetry: true),
        };
      },
    );
  }
}
