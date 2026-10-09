import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class TravelSafetyScreen extends StatefulWidget {
  const TravelSafetyScreen({super.key});

  @override
  State<TravelSafetyScreen> createState() => _TravelSafetyScreenState();
}

class _TravelSafetyScreenState extends State<TravelSafetyScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);

  Future<DocumentSnapshot<Map<String, dynamic>>>? profileFuture;

  String? userId;
  int profileVersion = 0;

  @override
  void initState() {
    super.initState();
    prepareProfile();
  }

  void prepareProfile() {
    userId = FirebaseAuth.instance.currentUser?.uid;
    profileVersion++;

    final uid = userId;

    profileFuture = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  void retry() {
    setState(() => prepareProfile());
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool checkAccount() {
    if (userId != null && FirebaseAuth.instance.currentUser?.uid == userId) {
      return true;
    }

    showMessage('Your account changed. Reopen this screen.');
    return false;
  }

  Future<void> openPhoneApp(String phone) async {
    if (!checkAccount()) return;

    final uid = userId;
    final number = phone.trim().replaceAll(RegExp(r'[\s()-]'), '');

    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(number)) {
      showMessage('Update the contact phone number in Profile.');
      return;
    }

    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: number));

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      if (!opened) {
        showMessage('No phone app is available. Copy the number instead.');
      }
    } catch (_) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      showMessage('Could not open a phone app. Copy the number instead.');
    }
  }

  Future<void> copyPhone(String phone) async {
    if (!checkAccount()) return;

    final uid = userId;

    try {
      await Clipboard.setData(ClipboardData(text: phone));

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      showMessage('Phone number copied.');
    } catch (_) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      showMessage('Could not copy. Select the displayed number to copy it.');
    }
  }

  Widget card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget messageCard({
    required String title,
    required String message,
    required IconData icon,
    bool allowRetry = false,
  }) {
    return card(
      child: Column(
        children: [
          Icon(icon, color: blue, size: 38),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
          ),
          if (allowRetry) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: retry,
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget contactCard({required String name, required String phone}) {
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline, color: blue, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency contact',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, color: blue, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    phone,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openPhoneApp(phone),
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.phone_outlined, size: 20),
              label: const Text('Open phone app'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => copyPhone(phone),
              style: OutlinedButton.styleFrom(
                foregroundColor: blue,
                side: const BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.copy_outlined, size: 19),
              label: const Text('Copy phone number'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Complete the call in your phone app. '
            'The number is saved from your profile and '
            'has not been verified.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget contactContent() {
    if (userId == null) {
      return messageCard(
        title: 'Sign in to view your contact',
        message:
            'Your emergency contact is saved '
            'with your TripLanka account.',
        icon: Icons.person_outline,
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey('$userId:$profileVersion'),
      future: profileFuture,
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser?.uid != userId) {
          return messageCard(
            title: 'Your account changed',
            message:
                'Reopen this screen to view '
                'the current account’s contact.',
            icon: Icons.person_outline,
          );
        }

        if (snapshot.hasError) {
          return messageCard(
            title: 'Could not load your contact',
            message: 'Check your connection and try again.',
            icon: Icons.cloud_off_outlined,
            allowRetry: true,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return card(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: blue)),
            ),
          );
        }

        final data = snapshot.data?.data();
        final name = (data?['emergencyName'] as String? ?? '').trim();
        final phone = (data?['emergencyPhone'] as String? ?? '').trim();

        if (name.isEmpty || phone.isEmpty) {
          return messageCard(
            title: 'Add an emergency contact',
            message:
                'Return to Profile, enter the contact '
                'name and phone number, and tap Save profile. '
                'Then reopen this screen or refresh the contact.',
            icon: Icons.contact_emergency_outlined,
          );
        }

        return contactCard(name: name, phone: phone);
      },
    );
  }

  Widget instructionStep({required String number, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              number,
              style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Travel safety',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        backgroundColor: background,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh contact',
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
                      Icon(
                        Icons.health_and_safety_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Keep your contact close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Access your saved contact and share '
                        'your journey details with someone you trust.',
                        style: TextStyle(color: Color(0xFFDCE8FF), height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                contactContent(),
                const SizedBox(height: 20),
                card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.share_outlined, color: blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Share your trip',
                              style: TextStyle(
                                color: navy,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      instructionStep(
                        number: '1',
                        text: 'Open Bookings and find your trip.',
                      ),
                      instructionStep(
                        number: '2',
                        text:
                            'Tap Share trip details '
                            'to copy the booking information.',
                      ),
                      instructionStep(
                        number: '3',
                        text:
                            'Paste the details into your '
                            'messaging app and send them '
                            'to your family or contact.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: blue, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'TripLanka opens an available phone app '
                          'with your contact’s number. It does not '
                          'automatically call anyone, send emergency '
                          'alerts, or share your live location.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
