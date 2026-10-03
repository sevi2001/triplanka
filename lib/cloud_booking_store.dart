import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_store.dart';

class CloudBookingEntry {
  const CloudBookingEntry({
    required this.id,
    required this.userId,
    required this.booking,
    required this.cancelled,
  });

  final String id;
  final String userId;
  final TripBooking booking;
  final bool cancelled;
}

class CloudBookingStore {
  CloudBookingStore._();

  static CollectionReference<Map<String, dynamic>> _bookingsFor(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bookings');
  }

  static String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please sign in again.');
    }

    return user.uid;
  }

  static Future<void> add(TripBooking booking) async {
    final userId = _requireUserId();

    await _bookingsFor(userId).add({
      ...booking.toJson(),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Retained for compatibility with existing code.
  static Stream<List<TripBooking>> watch(String userId) {
    return watchEntries(userId).map(
      (entries) =>
          List<TripBooking>.unmodifiable(entries.map((entry) => entry.booking)),
    );
  }

  static Stream<List<CloudBookingEntry>> watchEntries(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('A user ID is required.');
    }

    return _bookingsFor(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<CloudBookingEntry>.unmodifiable(
            snapshot.docs.map((document) {
              final data = document.data();

              return CloudBookingEntry(
                id: document.id,
                userId: userId,
                booking: TripBooking.fromJson(data),
                cancelled: data['status'] == 'cancelled',
              );
            }),
          ),
        );
  }

  static Future<void> cancel(CloudBookingEntry entry) async {
    final userId = _requireUserId();

    if (userId != entry.userId) {
      throw StateError('Your account changed. Reopen your bookings.');
    }

    await _bookingsFor(userId).doc(entry.id).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}
