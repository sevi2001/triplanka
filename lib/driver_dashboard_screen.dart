import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'driver_registration_screen.dart';
import 'driver_requests_screen.dart';
import 'driver_assigned_trips_screen.dart';
import 'trip_request_store.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);
  StreamSubscription<User?>? authSubscription;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? driverStream;
  Stream<List<TripRequestEntry>>? assignedTripsStream;
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
    streamVersion++;
    assignedTripsStream = user == null
        ? null
        : TripRequestStore.watchAssigned(user.uid);
    driverStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .snapshots();
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

  bool checkAccount() {
    final currentId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && currentId == userId) {
      return true;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Your account changed. Refresh the dashboard.'),
        ),
      );
    return false;
  }

  void openRegistration() {
    if (!checkAccount()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DriverRegistrationScreen()),
    );
  }

  void openRequests() {
    if (!checkAccount()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DriverRequestsScreen()),
    );
  }

  void openAssignedTrips() {
    if (!checkAccount()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DriverAssignedTripsScreen(),
      ),
    );
  }

  String readText(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'Not provided';
  }

  Widget card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget informationRow({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: blue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget messageCard({
    required String title,
    required String message,
    bool allowRetry = false,
    bool allowRegistration = false,
  }) {
    return card(
      child: Column(
        children: [
          const Icon(Icons.directions_car_outlined, color: blue, size: 44),
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
          if (allowRetry || allowRegistration) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: allowRegistration ? openRegistration : retry,
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
              child: Text(
                allowRegistration ? 'Register as driver' : 'Try again',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget summaryMetric({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: blue, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget ratingSummary() {
    final accountId = userId;
    if (accountId == null) return const SizedBox.shrink();
    return StreamBuilder<List<TripRequestEntry>>(
      key: ValueKey('ratings:$accountId:$streamVersion'),
      stream: assignedTripsStream,
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser?.uid != accountId) {
          return const SizedBox.shrink();
        }
        return card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_outline_rounded, color: blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your trip summary',
                      style: TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError) ...[
                const Text(
                  'Could not load your ratings and trip totals. '
                  'Check your connection and try again.',
                  style: TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ] else if (!snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: blue),
                  ),
                )
              else
                summaryResults(snapshot.data!, accountId),
            ],
          ),
        );
      },
    );
  }

  Widget summaryResults(List<TripRequestEntry> entries, String driverId) {
    final completed = entries
        .where((entry) => entry.driverId == driverId && entry.completed)
        .toList();
    final ratings = completed
        .map((entry) => entry.ratingStars)
        .whereType<int>()
        .where((stars) => stars >= 1 && stars <= 5)
        .toList();
    final sum = ratings.fold<int>(0, (total, stars) => total + stars);
    final average = ratings.isEmpty
        ? null
        : (sum / ratings.length).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            summaryMetric(
              value: average == null ? '—' : '$average / 5',
              label: 'Average rating',
              icon: Icons.star_rounded,
            ),
            summaryMetric(
              value: '${ratings.length}',
              label: 'Rated trips',
              icon: Icons.rate_review_outlined,
            ),
            summaryMetric(
              value: '${completed.length}',
              label: 'Completed trips',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          ratings.isEmpty
              ? 'No ratings yet. Passenger feedback will appear '
                    'after completed trips are rated.'
              : 'Your average uses passenger ratings from completed trips. '
                    'Unrated trips are excluded from the average.',
          style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: openAssignedTrips,
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('View trips and feedback'),
        ),
      ],
    );
  }

  Widget driverDetails(Map<String, dynamic> data) {
    final storedStatus = data['status'];
    final status = storedStatus is String ? storedStatus : 'unknown';
    final pending = status == 'pending';
    final approved = status == 'approved';
    final statusTitle = switch (status) {
      'pending' => 'Approval pending',
      'approved' => 'Approved',
      'rejected' => 'Registration not approved',
      'suspended' => 'Driver access suspended',
      _ => 'Status unavailable',
    };
    final statusMessage = switch (status) {
      'pending' =>
        'Your registration is saved. You can update your details '
            'while approval is pending.',
      'approved' =>
        'You can view and accept available demo trip requests '
            'that match your vehicle and passenger capacity.',
      'rejected' =>
        'Your registration has not been approved. '
            'Contact the app administrator for further information.',
      'suspended' => 'Your driver access is currently suspended.',
      _ => 'Refresh the dashboard or contact the app administrator.',
    };
    final statusColor = approved
        ? const Color(0xFF159A75)
        : pending
        ? const Color(0xFFC48616)
        : const Color(0xFFD94D64);
    final seats = data['passengerCapacity'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    approved ? Icons.check_circle_outline : Icons.info_outline,
                    color: statusColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusTitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                statusMessage,
                style: const TextStyle(color: muted, height: 1.5, fontSize: 13),
              ),
            ],
          ),
        ),
        if (approved) ratingSummary(),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver and vehicle',
                style: TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              informationRow(
                title: 'Driver name',
                value: readText(data, 'name'),
                icon: Icons.person_outline,
              ),
              informationRow(
                title: 'Phone number',
                value: readText(data, 'phone'),
                icon: Icons.phone_outlined,
              ),
              informationRow(
                title: 'Vehicle type',
                value: readText(data, 'vehicleType'),
                icon: Icons.directions_car_outlined,
              ),
              informationRow(
                title: 'Registration number',
                value: readText(data, 'registrationNumber'),
                icon: Icons.badge_outlined,
              ),
              informationRow(
                title: 'Passenger seats',
                value: seats is int ? '$seats' : 'Not provided',
                icon: Icons.groups_outlined,
              ),
              if (pending) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openRegistration,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit registration'),
                  ),
                ),
              ],
            ],
          ),
        ),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.route_outlined, color: blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Trip requests',
                      style: TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                approved
                    ? 'Find available demo requests that fit your vehicle '
                          'and choose a trip to accept.'
                    : 'Available requests will become accessible '
                          'when your driver profile is approved.',
                style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
              if (approved) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: openRequests,
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('View available requests'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openAssignedTrips,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('My accepted trips'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use a different passenger account to create '
                  'a test request. You cannot accept your own trip.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget dashboardContent() {
    if (userId == null) {
      return messageCard(
        title: 'Sign in first',
        message: 'Sign in to view your driver dashboard.',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey('$userId:$streamVersion'),
      stream: driverStream,
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser?.uid != userId) {
          return messageCard(
            title: 'Account changed',
            message: 'Refresh the dashboard to continue.',
            allowRetry: true,
          );
        }
        if (snapshot.hasError) {
          return messageCard(
            title: 'Could not load your driver profile',
            message: 'Check your connection and try again.',
            allowRetry: true,
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: blue)),
          );
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return messageCard(
            title: 'Start your driver registration',
            message:
                'Add your driver and vehicle details '
                'to create a private registration.',
            allowRegistration: true,
          );
        }
        return driverDetails(data);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Driver dashboard'),
        backgroundColor: background,
        foregroundColor: navy,
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
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
                  margin: const EdgeInsets.only(bottom: 20),
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
                      Icon(
                        Icons.directions_car_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Your driver space',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage your registration, view your vehicle '
                        'details and find available trip requests.',
                        style: TextStyle(color: Color(0xFFDCE8FF), height: 1.5),
                      ),
                    ],
                  ),
                ),
                dashboardContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
