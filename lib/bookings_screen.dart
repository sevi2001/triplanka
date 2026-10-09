import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_store.dart';
import 'cloud_booking_store.dart';
import 'driver_rating_screen.dart';
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
                onRetry: retry,
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'My bookings',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh bookings',
                      onPressed: retry,
                      icon: const Icon(Icons.refresh, color: _blue),
                    ),
                  ],
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
                  'Upcoming includes trips waiting for a driver, '
                  'accepted trips and earlier bookings without a request. '
                  'Trips are grouped by status, not departure date.',
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
  const BookingCard({super.key, required this.entry, this.onRetry});
  final CloudBookingEntry entry;
  final VoidCallback? onRetry;
  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  bool cancelling = false;
  bool confirmingCancellation = false;
  bool openingPhone = false;
  bool ratingFlowOpen = false;
  bool savingRating = false;
  CloudBookingEntry get entry => widget.entry;
  TripBooking get booking => entry.booking;
  bool get sameAccount =>
      FirebaseAuth.instance.currentUser?.uid == entry.userId;
  bool validCoordinates(TripCoordinates? point) {
    return point != null &&
        point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  Color get statusColor {
    if (entry.cancelled) return _red;
    return switch (entry.status) {
      'in_progress' => _amber,
      'accepted' || 'completed' => _green,
      'pending' => _blue,
      _ => _muted,
    };
  }

  String get badgeLabel {
    if (entry.cancelled) return 'Cancelled';
    return switch (entry.status) {
      'pending' => 'Waiting',
      'accepted' => 'Accepted',
      'in_progress' => 'In progress',
      'completed' => 'Completed',
      'legacy' => 'Earlier booking',
      _ => 'Unavailable',
    };
  }

  void showMessage(String message) {
    if (!mounted || !sameAccount) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openPhoneApp() async {
    if (!sameAccount || openingPhone || !entry.hasAssignedDriver) return;
    final number = entry.driverPhone.trim().replaceAll(RegExp(r'[\s()-]'), '');
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
      showMessage('Could not open a phone app. Copy the number instead.');
    } finally {
      if (mounted) {
        setState(() => openingPhone = false);
      }
    }
  }

  Future<void> cancelBooking() async {
    if (!sameAccount ||
        cancelling ||
        confirmingCancellation ||
        !entry.canCancel) {
      return;
    }
    final originalEntry = entry;
    confirmingCancellation = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel demo booking?'),
          content: Text(
            '${originalEntry.booking.pickup} → '
            '${originalEntry.booking.destination}\n\n'
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
        !entry.canCancel) {
      return;
    }
    // This card may disappear from the selected filter after cancellation.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => cancelling = true);
    try {
      await CloudBookingStore.cancel(originalEntry);
      if (FirebaseAuth.instance.currentUser?.uid != originalEntry.userId) {
        return;
      }
      if (messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Demo booking cancelled.')),
          );
      }
    } catch (error) {
      if (FirebaseAuth.instance.currentUser?.uid != originalEntry.userId) {
        return;
      }
      final message = error is StateError
          ? error.message.toString()
          : 'Could not cancel. Check your connection and try again.';
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

  Future<void> rateDriver() async {
    if (!sameAccount || ratingFlowOpen || savingRating || !entry.canRate) {
      return;
    }
    final originalEntry = entry;
    setState(() => ratingFlowOpen = true);
    try {
      final draft = await Navigator.of(context).push<DriverRatingDraft>(
        MaterialPageRoute<DriverRatingDraft>(
          builder: (_) => DriverRatingScreen(
            driverName: originalEntry.driverName,
            destination: originalEntry.booking.destination,
          ),
        ),
      );
      if (!mounted || !sameAccount || draft == null || !entry.canRate) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submit your rating?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${draft.stars} out of 5 stars'),
                if (draft.comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(draft.comment),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Your assigned driver can see this rating and review. '
                  'You can submit it once for this trip.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      );
      if (!mounted || !sameAccount || confirmed != true || !entry.canRate) {
        return;
      }
      setState(() => savingRating = true);
      await CloudBookingStore.rateDriver(
        originalEntry,
        stars: draft.stars,
        comment: draft.comment,
      );
      if (!mounted || !sameAccount) return;
      showMessage('Thank you! Your rating has been saved.');
    } catch (error) {
      if (!mounted || !sameAccount) return;
      showMessage(
        error is StateError
            ? error.message.toString()
            : error is ArgumentError
            ? error.message.toString()
            : 'Could not save your rating. Check your connection '
                  'and Firebase rules, then try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          ratingFlowOpen = false;
          savingRating = false;
        });
      }
    }
  }

  Widget ratingPanel() {
    if (!entry.completed) return const SizedBox.shrink();
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
          Text(
            stars == null ? 'How was your journey?' : 'Your driver rating',
            style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (stars != null) ...[
            Semantics(
              label: 'Your rating: $stars out of 5 stars',
              child: ExcludeSemantics(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    for (int index = 1; index <= 5; index++)
                      Icon(
                        index <= stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: _amber,
                        size: 25,
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '$stars/5',
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entry.ratingComment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.ratingComment,
                style: const TextStyle(color: _navy, height: 1.5),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Rating submitted. Thank you for your feedback.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ] else if (entry.canRate) ...[
            const Text(
              'Rate your experience with the driver for this completed trip.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ratingFlowOpen || savingRating ? null : rateDriver,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.star_outline_rounded),
                label: Text(
                  savingRating
                      ? 'Saving rating...'
                      : ratingFlowOpen
                      ? 'Rating in progress...'
                      : 'Rate driver',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> shareTripDetails() async {
    if (!sameAccount) return;
    final currentEntry = entry;
    final trip = currentEntry.booking;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(trip.departure);
    final time = TimeOfDay.fromDateTime(trip.departure).format(context);
    final details = [
      'TripLanka — Trip details',
      '',
      'Status: ${currentEntry.statusLabel}',
      'Pickup: ${trip.pickup}',
      'Destination: ${trip.destination}',
      if (trip.stops.isNotEmpty) 'Stops: ${trip.stops.join(' → ')}',
      'Departure / request time: $date at $time',
      'Vehicle: ${trip.vehicle}',
      'Passengers: ${trip.passengers}',
      if (currentEntry.hasAssignedDriver) ...[
        '',
        if (currentEntry.driverName.isNotEmpty)
          'Driver: ${currentEntry.driverName}',
        if (currentEntry.driverPhone.isNotEmpty)
          'Driver phone: ${currentEntry.driverPhone}',
        if (currentEntry.driverRegistration.isNotEmpty)
          'Vehicle registration: ${currentEntry.driverRegistration}',
      ],
      if (trip.notes.isNotEmpty) 'Notes: ${trip.notes}',
      '',
      'Demo booking. This message does not include live location.',
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
            TripMapScreen(booking: booking, requestId: entry.requestId),
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
    const valueStyle = TextStyle(
      color: _navy,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
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
                  SelectableText(value, style: valueStyle)
                else
                  Text(value, style: valueStyle),
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

  Widget actionButton(String label, IconData icon, VoidCallback onPressed) {
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

  Widget assignmentPanel() {
    final message = entry.cancelled
        ? 'This booking has been cancelled.'
        : switch (entry.status) {
            'pending' =>
              'Your request is available to matching approved drivers.',
            'accepted' => 'A driver has accepted this demo request.',
            'in_progress' => 'Your driver has started this journey.',
            'completed' => 'Your driver has marked this journey as completed.',
            'legacy' =>
              'This earlier booking was not posted as a driver request.',
            _ => 'Could not verify the trip status. Refresh your bookings.',
          };
    final panelColor = entry.inProgress
        ? const Color(0xFFFFF8EB)
        : entry.hasAssignedDriver
        ? const Color(0xFFEEF9F5)
        : _background;
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
                entry.hasAssignedDriver
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: statusColor,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          if (entry.hasAssignedDriver) ...[
            const SizedBox(height: 10),
            informationRow(
              label: 'Driver name',
              value: entry.driverName.isEmpty
                  ? 'Not provided'
                  : entry.driverName,
              icon: Icons.person_outline,
            ),
            informationRow(
              label: 'Driver phone',
              value: entry.driverPhone.isEmpty
                  ? 'Not provided'
                  : entry.driverPhone,
              icon: Icons.phone_outlined,
              selectable: true,
            ),
            informationRow(
              label: 'Vehicle registration',
              value: entry.driverRegistration.isEmpty
                  ? 'Not provided'
                  : entry.driverRegistration,
              icon: Icons.badge_outlined,
            ),
            if (entry.driverPhone.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: openingPhone ? null : openPhoneApp,
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
          if (!entry.cancelled &&
              entry.status == 'unavailable' &&
              widget.onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh bookings'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!sameAccount) return const SizedBox.shrink();
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(booking.departure);
    final time = TimeOfDay.fromDateTime(booking.departure).format(context);
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
          assignmentPanel(),
          if (entry.completed) ...[const SizedBox(height: 16), ratingPanel()],
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
                'Split the cost',
                Icons.groups_outlined,
                openSplitCost,
              ),
              actionButton(
                'Share trip details',
                Icons.share_outlined,
                shareTripDetails,
              ),
              actionButton(
                'Travel safety',
                Icons.health_and_safety_outlined,
                openSafety,
              ),
            ],
          ),
          if (entry.canCancel) ...[
            const SizedBox(height: 8),
            const Divider(color: _border),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: cancelling ? null : cancelBooking,
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
}
