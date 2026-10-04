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
import 'driver_dashboard_screen.dart';

const tripBlue = Color(0xFF2563EB);
const tripNavy = Color(0xFF14213D);
const tripBackground = Color(0xFFF5F7FB);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
                'Check your Firebase configuration, '
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

  // Use false only for Home-screen tests.
  final bool useAuthentication;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripLanka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: tripBlue,
          primary: tripBlue,
        ),
        scaffoldBackgroundColor: tripBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: tripBackground,
          foregroundColor: tripNavy,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFE0EAFF),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: tripBlue, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: useAuthentication
          ? AuthGate(loadMapTiles: loadMapTiles)
          : MainScreen(loadMapTiles: loadMapTiles),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.loadMapTiles});

  final bool loadMapTiles;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> authStream;

  @override
  void initState() {
    super.initState();
    authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStream,
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
          loadMapTiles: widget.loadMapTiles,
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

    if (email.isEmpty) {
      return 'Enter your email address';
    }

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
    if (busy || !(formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text;
    final createAccount = creatingAccount;

    setState(() {
      busy = true;
      message = null;
    });

    try {
      if (createAccount) {
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

      // AuthGate opens Home after successful authentication.
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

    final email = emailController.text.trim();

    setState(() {
      busy = true;
      message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

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
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: tripBlue,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.explore,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TripLanka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: tripNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your next journey starts here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    creatingAccount ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: tripNavy,
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(message!),
                    ),
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
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            formKey.currentState?.reset();

                            setState(() {
                              creatingAccount = !creatingAccount;
                              passwordController.clear();
                              message = null;
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
              title: const Text(
                'TripLanka',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                TextButton.icon(
                  onPressed: signingOut ? null : signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(signingOut ? 'Signing out...' : 'Sign out'),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeScreen(loadMapTiles: widget.loadMapTiles),
          // Avoid accessing Firebase in authentication-free Home tests.
          if (widget.showAccount)
            const BookingsScreen()
          else
            const Center(child: Text('Sign in to view bookings.')),
          if (widget.showAccount)
            const ProfileScreen()
          else
            const Center(child: Text('Sign in to view your profile.')),
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

    final selected = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Search pickup' : 'Search destination',
          confirmLabel: isPickup ? 'Use this pickup' : 'Use this destination',
        ),
      ),
    );

    if (!mounted || selected == null) return;

    final coordinates = TripCoordinates(
      latitude: selected.point.latitude,
      longitude: selected.point.longitude,
    );

    setState(() {
      if (isPickup) {
        pickupController.text = selected.name;
        pickupCoordinates = coordinates;
      } else {
        destinationController.text = selected.name;
        destinationCoordinates = coordinates;
      }
    });
  }

  void openBooking(String service) {
    FocusScope.of(context).unfocus();

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();
    final selectedPickup = pickupCoordinates;
    final selectedDestination = destinationCoordinates;

    final Widget screen;

    switch (service) {
      case 'Ride now':
        screen = RideNowScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: selectedPickup,
          destinationCoordinates: selectedDestination,
        );
        break;
      case 'Plan a trip':
        screen = PlanTripScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: selectedPickup,
          destinationCoordinates: selectedDestination,
        );
        break;
      case 'Airport transfer':
        screen = AirportTransferScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: selectedPickup,
          destinationCoordinates: selectedDestination,
        );
        break;
      case 'Full-day driver':
        screen = FullDayDriverScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: selectedPickup,
          destinationCoordinates: selectedDestination,
        );
        break;
      default:
        screen = BookingScreen(
          service: service,
          pickup: pickup,
          destination: destination,
        );
    }

    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Widget locationField({
    required String label,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required bool isPickup,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) {
        setState(() {
          if (isPickup) {
            pickupCoordinates = null;
          } else {
            destinationCoordinates = null;
          }
        });
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        suffixIcon: IconButton(
          tooltip: isPickup ? 'Search pickup' : 'Search destination',
          onPressed: () => searchLocation(isPickup: isPickup),
          icon: const Icon(Icons.search, color: tripBlue),
        ),
        filled: true,
        fillColor: tripBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                    colors: [tripBlue, Color(0xFF1746A2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.explore, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Let’s explore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Your next journey\nstarts here.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'A quick ride, a day out, or a trip with friends.',
                      style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE7ECF3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Where are you going?',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: tripNavy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    locationField(
                      label: 'Pickup location',
                      icon: Icons.my_location,
                      color: const Color(0xFF0D9488),
                      controller: pickupController,
                      isPickup: true,
                    ),
                    const SizedBox(height: 12),
                    locationField(
                      label: 'Destination',
                      icon: Icons.location_on,
                      color: const Color(0xFFF43F5E),
                      controller: destinationController,
                      isPickup: false,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap the search icon to select a place on the map.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (pickupCoordinates != null ||
                        destinationCoordinates != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (pickupCoordinates != null)
                            const Chip(
                              avatar: Icon(
                                Icons.check_circle,
                                size: 17,
                                color: Color(0xFF0D9488),
                              ),
                              label: Text('Pickup selected'),
                            ),
                          if (destinationCoordinates != null)
                            const Chip(
                              avatar: Icon(
                                Icons.check_circle,
                                size: 17,
                                color: Color(0xFF0D9488),
                              ),
                              label: Text('Destination selected'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ServiceCard(
                title: 'Drive with TripLanka',
                subtitle: 'Your driver dashboard and registration',
                icon: Icons.badge_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DriverDashboardScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              const Text(
                'Choose your journey',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: tripNavy,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 300 ? 1 : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: ServiceCard(
                          title: 'Ride now',
                          subtitle: 'For a quick journey',
                          icon: Icons.local_taxi_outlined,
                          onTap: () => openBooking('Ride now'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: ServiceCard(
                          title: 'Plan a trip',
                          subtitle: 'Dates, stops, and friends',
                          icon: Icons.calendar_month_outlined,
                          onTap: () => openBooking('Plan a trip'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: ServiceCard(
                          title: 'Airport transfer',
                          subtitle: 'Plan your airport journey',
                          icon: Icons.flight_takeoff,
                          onTap: () => openBooking('Airport transfer'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: ServiceCard(
                          title: 'Full-day driver',
                          subtitle: 'Explore at your own pace',
                          icon: Icons.directions_car_outlined,
                          onTap: () => openBooking('Full-day driver'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              const Text(
                'Explore the map',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: tripNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Map preview centered on Colombo.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 200,
                  child: HomeMap(loadTiles: widget.loadMapTiles),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.black54, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo bookings. Driver matching and live '
                      'tracking are not connected yet.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7ECF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tripBlue, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: tripNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.arrow_forward, color: tripBlue, size: 20),
            ],
          ),
        ),
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
