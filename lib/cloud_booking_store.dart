import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_store.dart';

class CloudBookingEntry {
  const CloudBookingEntry({
    required this.id,
    required this.userId,
    required this.booking,
    required this.cancelled,
    this.requestId,
  });

  final String id;
  final String userId;
  final TripBooking booking;
  final bool cancelled;

  // Older bookings do not have a shared trip request.
  final String? requestId;
}

class CloudBookingStore {
  CloudBookingStore._();

  static FirebaseFirestore get _database => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _bookingsFor(String userId) {
    return _database.collection('users').doc(userId).collection('bookings');
  }

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _database.collection('tripRequests');

  static String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please sign in again.');
    }

    return user.uid;
  }

  static Future<void> add(TripBooking booking) async {
    final userId = _requireUserId();

    if (booking.pickup.trim().isEmpty || booking.destination.trim().isEmpty) {
      throw ArgumentError('Pickup and destination are required.');
    }

    if (booking.passengers < 1 || booking.passengers > 15) {
      throw ArgumentError('Choose between 1 and 15 passengers.');
    }

    if (!const ['Tuk-tuk', 'Car', 'Van', 'Minibus'].contains(booking.vehicle)) {
      throw ArgumentError('Choose a supported vehicle type.');
    }

    final bookingDocument = _bookingsFor(userId).doc();

    // The shared request uses the same ID as the private booking.
    final requestDocument = _requests.doc(bookingDocument.id);
    final tripData = booking.toJson();

    final batch = _database.batch();

    batch.set(bookingDocument, {
      ...tripData,
      'status': 'active',
      'requestId': requestDocument.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(requestDocument, {
      'ownerId': userId,
      'bookingId': bookingDocument.id,
      'trip': tripData,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

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
              final storedRequestId = data['requestId'];

              return CloudBookingEntry(
                id: document.id,
                userId: userId,
                booking: TripBooking.fromJson(data),
                cancelled: data['status'] == 'cancelled',
                requestId:
                    storedRequestId is String && storedRequestId.isNotEmpty
                    ? storedRequestId
                    : null,
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

    final bookingDocument = _bookingsFor(userId).doc(entry.id);

    await _database.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingDocument);

      if (!bookingSnapshot.exists) {
        throw StateError('This booking no longer exists.');
      }

      final data = bookingSnapshot.data()!;
      final storedRequestId = data['requestId'];

      DocumentReference<Map<String, dynamic>>? requestDocument;

      if (storedRequestId is String && storedRequestId.isNotEmpty) {
        requestDocument = _requests.doc(storedRequestId);

        final requestSnapshot = await transaction.get(requestDocument);

        if (!requestSnapshot.exists) {
          throw StateError(
            'The trip request is missing. Please try again later.',
          );
        }

        final requestData = requestSnapshot.data()!;

        if (requestData['ownerId'] != userId ||
            requestData['bookingId'] != entry.id) {
          throw StateError('The trip request does not match.');
        }

        final requestStatus = requestData['status'];

        if (requestStatus != 'pending' &&
            requestStatus != 'accepted' &&
            requestStatus != 'cancelled') {
          throw StateError('This request is no longer pending.');
        }
      }

      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError('Your account changed.');
      }

      transaction.update(bookingDocument, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (requestDocument != null) {
        // Already-cancelled requests need no additional write.
        // The booking can still be brought into the cancelled state.
        final alreadyCancelled = data['status'] == 'cancelled';

        if (!alreadyCancelled) {
          transaction.update(requestDocument, {
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }
}
