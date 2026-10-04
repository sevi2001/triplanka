import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'driver_registration_screen.dart';

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

  String? userId;
  int streamVersion = 0;

  @override
  void initState() {
    super.initState();

    setAccount(FirebaseAuth.instance.currentUser);

    authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == userId) return;

      setState(() => setAccount(user));
    });
  }

  void setAccount(User? user) {
    userId = user?.uid;
    streamVersion++;

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

  void openRegistration() {
    if (userId == null || FirebaseAuth.instance.currentUser?.uid != userId) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DriverRegistrationScreen()),
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
          Icon(icon, color: blue, size: 22),
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

  Widget driverDetails(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'unknown';
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
        'Your registration is saved. '
            'You can update your details while approval is pending.',
      'approved' =>
        'Your profile is marked approved. '
            'Trip requests and acceptance will be connected next.',
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
                      'Assigned trips',
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
                    ? 'Trip assignment is not connected yet.'
                    : 'Trip access requires an approved driver profile. '
                          'Assignment is not connected yet.',
                style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
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
                        'View your registration and vehicle details.',
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
