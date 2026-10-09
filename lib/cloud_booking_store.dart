import 'dart:async';
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
    this.status = 'legacy',
    this.driverName = '',
    this.driverPhone = '',
    this.driverRegistration = '',
    this.ratingStars,
    this.ratingComment = '',
  });
  final String id;
  final String userId;
  final TripBooking booking;
  final bool cancelled;
  final String? requestId;
  final String status;
  final String driverName;
  final String driverPhone;
  final String driverRegistration;
  final int? ratingStars;
  final String ratingComment;

  bool get hasRating => ratingStars != null;
  bool get canRate => completed && requestId != null && !hasRating;
  bool get upcoming =>
      !cancelled &&
      (status == 'pending' || status == 'accepted' || status == 'legacy');
  bool get inProgress => !cancelled && status == 'in_progress';
  bool get completed => !cancelled && status == 'completed';
  bool get hasAssignedDriver =>
      !cancelled &&
      (status == 'accepted' ||
          status == 'in_progress' ||
          status == 'completed');
  bool get canCancel => upcoming;
  String get statusLabel {
    if (cancelled) return 'Cancelled';
    return switch (status) {
      'pending' => 'Waiting for driver',
      'accepted' => 'Driver accepted',
      'in_progress' => 'Trip in progress',
      'completed' => 'Trip completed',
      'legacy' => 'Earlier booking',
      _ => 'Status unavailable',
    };
  }
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
    if (_requireUserId() != userId) {
      throw StateError('Sign in with the correct passenger account.');
    }
    late final StreamController<List<CloudBookingEntry>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    bookingSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    requestSubscription;
    QuerySnapshot<Map<String, dynamic>>? bookingSnapshot;
    QuerySnapshot<Map<String, dynamic>>? requestSnapshot;
    void emitEntries() {
      if (controller.isClosed ||
          bookingSnapshot == null ||
          requestSnapshot == null) {
        return;
      }
      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        controller.addError(
          StateError('Your account changed. Reopen your bookings.'),
        );
        return;
      }
      try {
        final requestDataById = {
          for (final document in requestSnapshot!.docs)
            document.id: document.data(),
        };
        final entries = bookingSnapshot!.docs.map((document) {
          final data = document.data();
          final storedRequestId = data['requestId'];
          final requestId =
              storedRequestId is String && storedRequestId.trim().isNotEmpty
              ? storedRequestId.trim()
              : null;
          final requestData = requestId == null
              ? null
              : requestDataById[requestId];
          final matchingRequest =
              requestData != null &&
              requestData['ownerId'] == userId &&
              requestData['bookingId'] == document.id;
          var status = requestId == null ? 'legacy' : 'unavailable';
          if (matchingRequest) {
            final storedStatus = requestData['status'];
            if (storedStatus is String &&
                const [
                  'pending',
                  'accepted',
                  'in_progress',
                  'completed',
                  'cancelled',
                ].contains(storedStatus)) {
              status = storedStatus;
            }
          }
          final cancelled =
              data['status'] == 'cancelled' || status == 'cancelled';
          String driverText(String key) {
            if (!matchingRequest) return '';
            final value = requestData[key];
            return value is String ? value.trim() : '';
          }
          final storedRating = matchingRequest
              ? requestData['ratingStars']
              : null;
          final ratingStars = storedRating is int &&
                  storedRating >= 1 && storedRating <= 5
              ? storedRating
              : null;

          return CloudBookingEntry(
            id: document.id,
            userId: userId,
            booking: TripBooking.fromJson(data),
            cancelled: cancelled,
            requestId: requestId,
            status: cancelled ? 'cancelled' : status,
            driverName: driverText('driverName'),
            driverPhone: driverText('driverPhone'),
            driverRegistration: driverText('driverRegistration'),
            ratingStars: ratingStars,
            ratingComment: driverText('ratingComment'),
          );
        }).toList();
        controller.add(List<CloudBookingEntry>.unmodifiable(entries));
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }
    controller = StreamController<List<CloudBookingEntry>>(
      onListen: () {
        bookingSubscription = _bookingsFor(userId)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen(
              (snapshot) {
                bookingSnapshot = snapshot;
                emitEntries();
              },
              onError: (Object error, StackTrace stackTrace) {
                bookingSnapshot = null;
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
        // Query only this passenger's requests.
        requestSubscription = _requests
            .where('ownerId', isEqualTo: userId)
            .snapshots()
            .listen(
              (snapshot) {
                requestSnapshot = snapshot;
                emitEntries();
              },
              onError: (Object error, StackTrace stackTrace) {
                requestSnapshot = null;
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
      },
      onCancel: () async {
        await Future.wait<void>([
          if (bookingSubscription != null) bookingSubscription!.cancel(),
          if (requestSubscription != null) requestSubscription!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
  static Future<void> rateDriver(
    CloudBookingEntry entry, {
    required int stars,
    String comment = '',
  }) async {
    final userId = _requireUserId();
    if (userId != entry.userId) {
      throw StateError('Your account changed. Reopen your bookings.');
    }
    if (stars < 1 || stars > 5) {
      throw ArgumentError('Choose between 1 and 5 stars.');
    }
    final review = comment.trim();
    if (review.length > 500) {
      throw ArgumentError('Keep your review within 500 characters.');
    }

    final bookingDocument = _bookingsFor(userId).doc(entry.id);
    await _database.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingDocument);
      final bookingData = bookingSnapshot.data();
      if (bookingData == null) {
        throw StateError('This booking no longer exists.');
      }
      final requestId = bookingData['requestId'];
      if (requestId is! String || requestId.trim().isEmpty ||
          requestId.contains('/')) {
        throw StateError('This earlier booking cannot be rated.');
      }
      final requestDocument = _requests.doc(requestId.trim());
      final requestSnapshot = await transaction.get(requestDocument);
      final request = requestSnapshot.data();
      if (request == null || request['ownerId'] != userId ||
          request['bookingId'] != entry.id) {
        throw StateError('The trip request does not match this booking.');
      }
      if (bookingData['status'] == 'cancelled' ||
          request['status'] != 'completed') {
        throw StateError('You can rate a driver after the trip is completed.');
      }
      final driverId = request['driverId'];
      if (driverId is! String || driverId.isEmpty || driverId == userId) {
        throw StateError('This trip does not have a valid assigned driver.');
      }
      if (request.containsKey('ratingStars')) {
        throw StateError('You have already rated this trip.');
      }
      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError('Your account changed.');
      }
      transaction.update(requestDocument, {
        'ratingStars': stars,
        'ratingComment': review,
        'ratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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
      bool requestAlreadyCancelled = false;
      if (storedRequestId is String && storedRequestId.trim().isNotEmpty) {
        requestDocument = _requests.doc(storedRequestId.trim());
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
        if (requestStatus == 'in_progress') {
          throw StateError('This trip has started and cannot be cancelled.');
        }
        if (requestStatus == 'completed') {
          throw StateError('A completed trip cannot be cancelled.');
        }
        if (requestStatus != 'pending' &&
            requestStatus != 'accepted' &&
            requestStatus != 'cancelled') {
          throw StateError('This trip cannot currently be cancelled.');
        }
        requestAlreadyCancelled = requestStatus == 'cancelled';
      }
      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError('Your account changed.');
      }
      // All transaction reads happen before these writes.
      if (data['status'] != 'cancelled') {
        transaction.update(bookingDocument, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
      if (requestDocument != null && !requestAlreadyCancelled) {
        transaction.update(requestDocument, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
