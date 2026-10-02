import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final preferences = SharedPreferencesAsync();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

  static const storageKey = 'triplanka_profile_v1';

  bool loading = true;
  bool saving = false;
  bool loadFailed = false;

  String? statusMessage;
  bool statusIsError = false;

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

  Future<void> loadProfile() async {
    setState(() {
      loading = true;
      loadFailed = false;
      statusMessage = null;
    });

    try {
      final stored = await preferences.getString(storageKey);

      if (!mounted) return;

      if (stored != null) {
        final data = jsonDecode(stored) as Map<String, dynamic>;

        nameController.text = data['name'] as String? ?? '';
        phoneController.text = data['phone'] as String? ?? '';
        emergencyNameController.text = data['emergencyName'] as String? ?? '';
        emergencyPhoneController.text = data['emergencyPhone'] as String? ?? '';
      }
    } catch (error) {
      debugPrint('Profile load failed: $error');

      if (!mounted) return;

      loadFailed = true;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String? validatePhone(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter a phone number';
    }

    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text)) {
      return 'Use digits and an optional country code';
    }

    final digits = text.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 9 || digits.length > 15) {
      return 'Enter a phone number with 9–15 digits';
    }

    return null;
  }

  Future<void> saveProfile() async {
    if (saving || loading || loadFailed) return;

    FocusScope.of(context).unfocus();

    final valid = formKey.currentState?.validate() ?? false;

    if (!valid) {
      setState(() {
        statusMessage =
            'Check the highlighted fields above. '
            'Enter your name and a valid phone number. '
            'For emergency contact, fill both fields '
            'or leave both empty.';
        statusIsError = true;
      });
      return;
    }

    setState(() {
      saving = true;
      statusMessage = 'Saving your profile...';
      statusIsError = false;
    });

    final data = {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'emergencyName': emergencyNameController.text.trim(),
      'emergencyPhone': emergencyPhoneController.text.trim(),
    };

    try {
      await preferences.setString(storageKey, jsonEncode(data));

      // Verify that the saved values can be read back.
      final stored = await preferences.getString(storageKey);

      if (stored == null) {
        throw StateError('Saved profile could not be read back.');
      }

      final restored = jsonDecode(stored) as Map<String, dynamic>;

      for (final entry in data.entries) {
        if (restored[entry.key] != entry.value) {
          throw StateError('Saved profile verification failed.');
        }
      }

      if (!mounted) return;

      setState(() {
        statusMessage = 'Profile saved successfully on this device.';
        statusIsError = false;
      });
    } catch (error) {
      debugPrint('Profile save failed: $error');

      if (!mounted) return;

      setState(() {
        statusMessage =
            'Could not save your profile. Please try again. '
            'Check the terminal for the error.';
        statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      onChanged: (_) {
        if (statusMessage != null) {
          setState(() {
            statusMessage = null;
          });
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (loadFailed) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Could not load your profile.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loadProfile,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'My profile',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(Icons.person, size: 48, color: Colors.teal),
                  ),
                ),
                const SizedBox(height: 24),
                profileField(
                  label: 'Full name',
                  icon: Icons.person_outline,
                  controller: nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                profileField(
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  controller: phoneController,
                  validator: validatePhone,
                  phone: true,
                ),
                const SizedBox(height: 28),
                const Text(
                  'Emergency contact',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optional. Fill both fields or leave both empty. '
                  'Saving this contact does not automatically '
                  'call or notify them.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                profileField(
                  label: 'Contact name',
                  icon: Icons.contact_emergency_outlined,
                  controller: emergencyNameController,
                  validator: (value) {
                    final hasPhone = emergencyPhoneController.text
                        .trim()
                        .isNotEmpty;

                    final hasName = value?.trim().isNotEmpty ?? false;

                    if (hasPhone && !hasName) {
                      return 'Enter the emergency contact name';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                profileField(
                  label: 'Contact phone number',
                  icon: Icons.phone_outlined,
                  controller: emergencyPhoneController,
                  phone: true,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final name = emergencyNameController.text.trim();

                    if (text.isEmpty && name.isEmpty) {
                      return null;
                    }

                    return validatePhone(value);
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Saved locally on this device. '
                  'This is not a verified account.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // Keep the result visible near the Save button.
                if (statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusIsError
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusMessage!,
                      style: TextStyle(
                        color: statusIsError
                            ? Colors.red.shade900
                            : Colors.teal.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                FilledButton(
                  onPressed: saving ? null : saveProfile,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(saving ? 'Saving...' : 'Save profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
