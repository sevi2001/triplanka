import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_store.dart';

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
      throw StateError('Sign in before accessing your bookings.');
    }

    return user.uid;
  }

  /// Saves a demo booking under the current user's account.
  /// This does not assign a driver or request a real ride.
  static Future<void> add(TripBooking booking) async {
    final userId = _requireUserId();

    await _bookingsFor(
      userId,
    ).add({...booking.toJson(), 'createdAt': FieldValue.serverTimestamp()});
  }

  /// Watches one user's bookings for changes.
  ///
  /// Supply the UID from the authentication screen so the subscription
  /// belongs to that account.
  static Stream<List<TripBooking>> watch(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('A user ID is required.');
    }

    return _bookingsFor(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<TripBooking>.unmodifiable(
            snapshot.docs.map(
              (document) => TripBooking.fromJson(document.data()),
            ),
          ),
        );
  }
}
