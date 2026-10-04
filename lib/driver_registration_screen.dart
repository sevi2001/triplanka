import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);

  static const capacities = {'Tuk-tuk': 3, 'Car': 4, 'Van': 8, 'Minibus': 15};

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final registrationController = TextEditingController();

  String vehicleType = 'Car';
  int passengerCapacity = 4;

  String? userId;
  String? status;
  String? loadError;

  bool loading = true;
  bool saving = false;
  bool exists = false;

  bool get editable => status == null || status == 'pending';

  @override
  void initState() {
    super.initState();
    loadDriver();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    registrationController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> driverDocument(String uid) {
    return FirebaseFirestore.instance.collection('drivers').doc(uid);
  }

  String errorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Could not access your driver profile. '
            'Check that the driver rules have been published.';
      }
      if (error.code == 'unavailable') {
        return 'Check your connection and try again.';
      }
    }

    return 'Could not complete the request. Please try again.';
  }

  Future<void> loadDriver() async {
    if (saving) return;

    setState(() {
      loading = true;
      loadError = null;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
        loadError = 'Sign in before registering as a driver.';
      });
      return;
    }

    userId = user.uid;

    try {
      final snapshot = await driverDocument(user.uid).get();

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      final data = snapshot.data();

      exists = snapshot.exists;
      status = data?['status'] as String?;

      nameController.text = data?['name'] as String? ?? '';
      phoneController.text = data?['phone'] as String? ?? '';
      registrationController.text =
          data?['registrationNumber'] as String? ?? '';

      final storedType = data?['vehicleType'];
      if (storedType is String && capacities.containsKey(storedType)) {
        vehicleType = storedType;
      }

      final storedCapacity = data?['passengerCapacity'];
      passengerCapacity = storedCapacity is num
          ? storedCapacity.toInt().clamp(1, capacities[vehicleType]!).toInt()
          : capacities[vehicleType]!;

      if (!exists) {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;
        if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

        nameController.text = profile.data()?['name'] as String? ?? '';
        phoneController.text = profile.data()?['phone'] as String? ?? '';
      }
    } catch (error) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      loadError = errorMessage(error);
    } finally {
      if (mounted && FirebaseAuth.instance.currentUser?.uid == user.uid) {
        setState(() => loading = false);
      }
    }
  }

  String? validatePhone(String? value) {
    final text = value?.trim() ?? '';

    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text)) {
      return 'Enter a valid phone number';
    }

    final number = text.replaceAll(RegExp(r'[\s()-]'), '');

    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(number)) {
      return 'Use 9–15 digits with an optional country code';
    }

    return null;
  }

  Future<void> saveDriver() async {
    if (saving || loading || !editable || loadError != null) return;

    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) return;

    final uid = userId;

    if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final data = <String, dynamic>{
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim().replaceAll(RegExp(r'[\s()-]'), ''),
      'vehicleType': vehicleType,
      'registrationNumber': registrationController.text.trim().toUpperCase(),
      'passengerCapacity': passengerCapacity,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    setState(() => saving = true);

    try {
      if (exists) {
        await driverDocument(uid).update(data);
      } else {
        await driverDocument(uid).set({
          ...data,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      setState(() {
        exists = true;
        status = 'pending';
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Driver profile saved. Approval is pending.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool phone = false,
    int maxLength = 100,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: editable && !saving,
        maxLength: maxLength,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixIcon: Icon(icon, color: blue),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver registration')),
        body: const Center(child: CircularProgressIndicator(color: blue)),
      );
    }

    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver registration')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loadDriver,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Driver registration'),
        backgroundColor: background,
        foregroundColor: navy,
      ),
      body: SafeArea(
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: blue,
                            borderRadius: BorderRadius.circular(22),
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
                                'Drive with TripLanka',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Save your driver and vehicle details.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (status != null) ...[
                          Text(
                            status == 'pending'
                                ? 'Approval pending'
                                : 'Registration status: $status',
                            style: const TextStyle(
                              color: blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        field(
                          label: 'Driver full name',
                          icon: Icons.person_outline,
                          controller: nameController,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your name'
                              : null,
                        ),
                        field(
                          label: 'Phone number',
                          icon: Icons.phone_outlined,
                          controller: phoneController,
                          validator: validatePhone,
                          phone: true,
                          maxLength: 30,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: vehicleType,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle type',
                            prefixIcon: Icon(
                              Icons.directions_car_outlined,
                              color: blue,
                            ),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            for (final type in capacities.keys)
                              DropdownMenuItem(value: type, child: Text(type)),
                          ],
                          onChanged: saving || !editable
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    vehicleType = value;
                                    passengerCapacity = capacities[value]!;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        field(
                          label: 'Vehicle registration number',
                          icon: Icons.badge_outlined,
                          controller: registrationController,
                          maxLength: 30,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter the vehicle registration number'
                              : null,
                        ),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Passenger seats\nExcluding the driver',
                                style: TextStyle(color: navy),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fewer seats',
                              onPressed:
                                  editable && !saving && passengerCapacity > 1
                                  ? () => setState(() => passengerCapacity--)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Text(
                              '$passengerCapacity',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              tooltip: 'More seats',
                              onPressed:
                                  editable &&
                                      !saving &&
                                      passengerCapacity <
                                          capacities[vehicleType]!
                                  ? () => setState(() => passengerCapacity++)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Registration saves a private driver profile. '
                          'Approval and trip acceptance are not connected '
                          'yet. Vehicle and phone details are unverified.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                        if (!editable) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Editing is available while approval is pending.',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving || !editable ? null : saveDriver,
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        saving
                            ? 'Saving...'
                            : exists
                            ? 'Update driver profile'
                            : 'Register as driver',
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
