import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const successMessage =
      'If an account uses this email, check your inbox and spam folder '
      'for a password reset link.';

  final formKey = GlobalKey<FormState>();
  late final TextEditingController emailController;
  bool sending = false;
  bool requested = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
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

  Future<void> sendResetEmail() async {
    if (sending || requested || !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final email = emailController.text.trim();
    setState(() {
      sending = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => requested = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'user-not-found') {
          requested = true;
        } else {
          errorMessage = switch (error.code) {
            'invalid-email' => 'Enter a valid email address.',
            'too-many-requests' => 'Too many attempts. Please try again later.',
            'network-request-failed' =>
              'Check your internet connection and try again.',
            'operation-not-allowed' =>
              'Password reset is unavailable. Contact app support.',
            _ => 'Could not request a reset. Please try again.',
          };
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Could not request a reset. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  const Center(
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Color(0xFFE8EFFF),
                      child: Icon(Icons.lock_reset, size: 46, color: blue),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Reset your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: navy,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter the email you used for TripLanka. '
                    'Use the link in your email to choose a new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: emailController,
                    enabled: !sending && !requested,
                    validator: validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) => sendResetEmail(),
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined, color: blue),
                    ),
                  ),
                  if (errorMessage != null || requested) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: requested
                            ? const Color(0xFFEEF9F5)
                            : const Color(0xFFFFEEF1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        requested ? successMessage : errorMessage!,
                        style: const TextStyle(color: navy, height: 1.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: sending || requested ? null : sendResetEmail,
                    icon: const Icon(Icons.outgoing_mail),
                    label: Text(
                      sending
                          ? 'Sending...'
                          : requested
                          ? 'Request submitted'
                          : 'Send reset email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to sign in'),
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
