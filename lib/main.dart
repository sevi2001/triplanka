import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'airport_transfer_screen.dart';
import 'booking_store.dart';
import 'bookings_screen.dart';
import 'firebase_options.dart';
import 'full_day_driver_screen.dart';
import 'home_map.dart';
import 'location_picker_screen.dart';
import 'plan_trip_screen.dart';
import 'profile_screen.dart';
import 'ride_now_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await BookingStore.load();

    runApp(const TripLankaApp());
  } catch (error) {
    debugPrint('App startup failed: $error');

    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not start TripLanka. '
                'Check your connection and Firebase configuration, '
                'then restart the app.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TripLankaApp extends StatelessWidget {
  const TripLankaApp({
    super.key,
    this.loadMapTiles = true,
    this.useAuthentication = true,
  });

  final bool loadMapTiles;

  // Set false only in tests that check the existing Home screen.
  final bool useAuthentication;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripLanka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: useAuthentication
          ? AuthGate(loadMapTiles: loadMapTiles)
          : MainScreen(loadMapTiles: loadMapTiles),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.loadMapTiles});

  final bool loadMapTiles;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Could not check your login. Restart the app.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return MainScreen(
          key: ValueKey(user.uid),
          loadMapTiles: loadMapTiles,
          showAccount: true,
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool creatingAccount = false;
  bool busy = false;
  bool hidePassword = true;

  String? message;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Enter your email address';

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String authError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already uses this email. Try signing in.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Could not sign in. Check your email and password.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Enable Email/Password in Firebase Authentication.';
      default:
        return 'Could not complete the request. Please try again.';
    }
  }

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      busy = true;
      message = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (creatingAccount) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // AuthGate opens Home when authentication succeeds.
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        message = authError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        message = 'Could not complete the request. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> resetPassword() async {
    if (busy) return;

    final emailError = validateEmail(emailController.text);

    if (emailError != null) {
      setState(() {
        message = emailError;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      busy = true;
      message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        message =
            'If an account uses this email, check your inbox '
            'and spam folder for a password reset link.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        message = authError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        message = 'Could not request a reset. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.explore, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'TripLanka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    creatingAccount ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    enabled: !busy,
                    obscureText: hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) => submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }

                      if (creatingAccount && value.length < 6) {
                        return 'Use at least 6 characters';
                      }

                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: busy
                            ? null
                            : () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Please wait...'
                          : creatingAccount
                          ? 'Create account'
                          : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              creatingAccount = !creatingAccount;
                              passwordController.clear();
                              message = null;
                              formKey.currentState?.reset();
                            });
                          },
                    child: Text(
                      creatingAccount
                          ? 'Already have an account? Sign in'
                          : 'New to TripLanka? Create an account',
                    ),
                  ),
                  if (!creatingAccount)
                    TextButton(
                      onPressed: busy ? null : resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.loadMapTiles = true,
    this.showAccount = false,
  });

  final bool loadMapTiles;
  final bool showAccount;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  bool signingOut = false;

  Future<void> signOut() async {
    if (signingOut) return;

    setState(() {
      signingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          signingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAccount
          ? AppBar(
              title: const Text('TripLanka'),
              actions: [
                TextButton.icon(
                  onPressed: signingOut ? null : signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(signingOut ? 'Signing out...' : 'Sign out'),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeScreen(loadMapTiles: widget.loadMapTiles),
          const BookingsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.loadMapTiles = true});

  final bool loadMapTiles;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final pickupController = TextEditingController();
  final destinationController = TextEditingController();

  TripCoordinates? pickupCoordinates;
  TripCoordinates? destinationCoordinates;

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> searchLocation({required bool isPickup}) async {
    FocusScope.of(context).unfocus();

    final location = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Find pickup' : 'Find destination',
          confirmLabel: isPickup ? 'Use this pickup' : 'Use this destination',
        ),
      ),
    );

    if (!mounted || location == null) return;

    final coordinates = TripCoordinates(
      latitude: location.point.latitude,
      longitude: location.point.longitude,
    );

    setState(() {
      if (isPickup) {
        pickupController.text = location.name;
        pickupCoordinates = coordinates;
      } else {
        destinationController.text = location.name;
        destinationCoordinates = coordinates;
      }
    });
  }

  void openBooking(String service) {
    FocusScope.of(context).unfocus();

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();
    final selectedPickupCoordinates = pickupCoordinates;
    final selectedDestinationCoordinates = destinationCoordinates;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          if (service == 'Ride now') {
            return RideNowScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          if (service == 'Plan a trip') {
            return PlanTripScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          if (service == 'Airport transfer') {
            return AirportTransferScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          if (service == 'Full-day driver') {
            return FullDayDriverScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          return BookingScreen(
            service: service,
            pickup: pickup,
            destination: destination,
          );
        },
      ),
    );
  }

  Widget locationField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget coordinateLabel(TripCoordinates coordinates) {
    return Text(
      'Map location selected: '
      '${coordinates.latitude.toStringAsFixed(5)}, '
      '${coordinates.longitude.toStringAsFixed(5)}',
      style: const TextStyle(color: Colors.teal, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPickup = pickupCoordinates;
    final selectedDestination = destinationCoordinates;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Row(
                children: [
                  Icon(Icons.explore, size: 32, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'TripLanka',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Where are you going?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Plan your next journey with us.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              locationField(
                label: 'Pickup location',
                icon: Icons.my_location,
                controller: pickupController,
                onChanged: (_) {
                  if (pickupCoordinates == null) return;

                  setState(() {
                    pickupCoordinates = null;
                  });
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => searchLocation(isPickup: true),
                  icon: const Icon(Icons.search),
                  label: const Text('Search pickup'),
                ),
              ),
              if (selectedPickup != null) coordinateLabel(selectedPickup),
              const SizedBox(height: 14),
              locationField(
                label: 'Destination',
                icon: Icons.location_on,
                controller: destinationController,
                onChanged: (_) {
                  if (destinationCoordinates == null) return;

                  setState(() {
                    destinationCoordinates = null;
                  });
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => searchLocation(isPickup: false),
                  icon: const Icon(Icons.search),
                  label: const Text('Search destination'),
                ),
              ),
              if (selectedDestination != null)
                coordinateLabel(selectedDestination),
              const SizedBox(height: 24),
              const Text(
                'Travel options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ServiceCard(
                title: 'Ride now',
                subtitle: 'Book a nearby driver',
                icon: Icons.local_taxi,
                onTap: () => openBooking('Ride now'),
              ),
              ServiceCard(
                title: 'Plan a trip',
                subtitle: 'Choose your date and stops',
                icon: Icons.calendar_month,
                onTap: () => openBooking('Plan a trip'),
              ),
              ServiceCard(
                title: 'Airport transfer',
                subtitle: 'Book an airport pickup or drop-off',
                icon: Icons.flight,
                onTap: () => openBooking('Airport transfer'),
              ),
              ServiceCard(
                title: 'Full-day driver',
                subtitle: 'Explore with a driver for the day',
                icon: Icons.directions_car,
                onTap: () => openBooking('Full-day driver'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Explore the map',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The marker shows Colombo. '
                'Your current location is not connected yet.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              HomeMap(loadTiles: widget.loadMapTiles),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Icon(icon, size: 30, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class BookingScreen extends StatelessWidget {
  const BookingScreen({
    super.key,
    required this.service,
    required this.pickup,
    required this.destination,
  });

  final String service;
  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(service)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Journey details',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text('Pickup'),
            subtitle: Text(pickup.isEmpty ? 'Not selected' : pickup),
          ),
          ListTile(
            title: const Text('Destination'),
            subtitle: Text(destination.isEmpty ? 'Not selected' : destination),
          ),
        ],
      ),
    );
  }
}
