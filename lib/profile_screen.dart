import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> profileDocument(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  bool sameAccount(String uid) {
    return mounted && FirebaseAuth.instance.currentUser?.uid == uid;
  }

  String readableError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Your account cannot access this profile. '
              'Please try signing in again.';
        case 'unavailable':
          return 'Check your internet connection and try again.';
        case 'unauthenticated':
          return 'Please sign out and sign in again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }

  Future<void> loadProfile() async {
    if (!mounted || saving) return;

    setState(() {
      loading = true;
      loadError = null;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
        loadError = 'Sign in to access your profile.';
      });
      return;
    }

    try {
      final document = await profileDocument(user.uid).get();

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      final data = document.data();

      nameController.text = data?['name'] as String? ?? '';
      phoneController.text = data?['phone'] as String? ?? '';
      emergencyNameController.text = data?['emergencyName'] as String? ?? '';
      emergencyPhoneController.text = data?['emergencyPhone'] as String? ?? '';
    } catch (error) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      debugPrint('Profile load failed: $error');
      loadError = readableError(error);
    } finally {
      if (sameAccount(user.uid)) {
        setState(() => loading = false);
      }
    }
  }

  String? validatePhone(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Enter a phone number';

    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text)) {
      return 'Use digits and an optional country code';
    }

    final digits = text.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 9 || digits.length > 15) {
      return 'Enter a valid phone number';
    }

    return null;
  }

  Future<void> saveProfile() async {
    if (loading || saving || loadError != null) return;

    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final data = <String, dynamic>{
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'emergencyName': emergencyNameController.text.trim(),
      'emergencyPhone': emergencyPhoneController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    setState(() => saving = true);

    try {
      await profileDocument(user.uid).set(data, SetOptions(merge: true));

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Profile saved to your account.')),
        );
    } catch (error) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      debugPrint('Profile save failed: $error');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(readableError(error))));
    } finally {
      if (sameAccount(user.uid)) {
        setState(() => saving = false);
      }
    }
  }

  Widget section({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
              Icon(icon, color: blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget profileField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool phone = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !saving,
      keyboardType: phone ? TextInputType.phone : TextInputType.name,
      textCapitalization: phone
          ? TextCapitalization.none
          : TextCapitalization.words,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      style: const TextStyle(color: navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: muted, fontSize: 13),
        prefixIcon: Icon(icon, color: blue, size: 22),
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget profileHeader(String email) {
    return Container(
      width: double.infinity,
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
      child: Column(
        children: [
          const CircleAvatar(
            radius: 38,
            backgroundColor: Color(0xFFE8F0FF),
            child: Icon(Icons.person_outline, color: blue, size: 44),
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameController,
            builder: (context, value, _) {
              final name = value.text.trim();

              return Text(
                name.isEmpty ? 'Your profile' : name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFDCE8FF), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SafeArea(
        child: ColoredBox(
          color: background,
          child: Center(child: CircularProgressIndicator(color: blue)),
        ),
      );
    }

    if (loadError != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, color: blue, size: 48),
                const SizedBox(height: 16),
                Text(
                  loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: loadProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return SafeArea(
      child: ColoredBox(
        color: background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        const Text(
                          'My profile',
                          style: TextStyle(
                            color: navy,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Keep your travel details up to date.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 22),
                        profileHeader(email),
                        section(
                          title: 'Personal details',
                          icon: Icons.person_outline,
                          child: Column(
                            children: [
                              profileField(
                                label: 'Full name',
                                icon: Icons.badge_outlined,
                                controller: nameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              profileField(
                                label: 'Phone number',
                                icon: Icons.phone_outlined,
                                controller: phoneController,
                                validator: validatePhone,
                                phone: true,
                              ),
                            ],
                          ),
                        ),
                        section(
                          title: 'Emergency contact',
                          icon: Icons.health_and_safety_outlined,
                          subtitle:
                              'Optional. Add someone you can '
                              'contact during your journey.',
                          child: Column(
                            children: [
                              profileField(
                                label: 'Contact name',
                                icon: Icons.person_outline,
                                controller: emergencyNameController,
                                validator: (value) {
                                  if (emergencyPhoneController.text
                                          .trim()
                                          .isNotEmpty &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Enter the emergency '
                                        'contact name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              profileField(
                                label: 'Contact phone number',
                                icon: Icons.phone_outlined,
                                controller: emergencyPhoneController,
                                phone: true,
                                validator: (value) {
                                  final text = value?.trim() ?? '';

                                  if (text.isEmpty &&
                                      emergencyNameController.text
                                          .trim()
                                          .isEmpty) {
                                    return null;
                                  }

                                  return validatePhone(value);
                                },
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: blue, size: 21),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Details are saved to your signed-in '
                                  'account. Phone numbers are not '
                                  'verified. Saving an emergency '
                                  'contact does not call or notify them.',
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        saving ? 'Saving...' : 'Save profile',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
