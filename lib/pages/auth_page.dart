import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool isLogin = false;
  bool isLoading = false;

  // "Tok" text & main button color
  final Color primaryColor = const Color(0xFF2E9712);

  Future<void> _login() async {
    setState(() => isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful!')),
      );

      // After successful login, go to MainPage
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      }
    } catch (e) {
      String errorMessage = 'Login failed. Please try again.';
      
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'Please sign up before logging in.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email format.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection and try again.';
            break;
          default:
            errorMessage = 'Login failed. Please try again.';
        }
      } else {
        // Handle non-Firebase exceptions
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        } else {
          errorMessage = 'Unexpected error occurred. Please try again.';
        }
      }
      print('Login error: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signup() async {
    setState(() => isLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup Successful! Please login now.')),
      );
      _emailController.clear();
      _passwordController.clear();

      // After successful signup, switch to login
      setState(() => isLogin = true);
    } catch (e) {
      String errorMessage = 'Signup failed. Please try again.';
      
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'Email already registered. Please login instead.';
            break;
          case 'weak-password':
            errorMessage = 'Password is too weak. Please use a stronger password.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email format.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection and try again.';
            break;
          default:
            errorMessage = 'Signup failed. Please try again.';
        }
      } else {
        // Handle non-Firebase exceptions
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        } else {
          errorMessage = 'Unexpected error occurred. Please try again.';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Draggable bottom sheet for "Forgot Password?"
  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final _resetEmailController = TextEditingController();

            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _resetEmailController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: 'Enter your email',
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final resetEmail = _resetEmailController.text.trim();
                        if (resetEmail.isEmpty) return;
                        try {
                          await _auth.sendPasswordResetEmail(email: resetEmail);
                          Navigator.pop(context); // close bottom sheet
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password reset email sent!')),
                          );
                        } catch (e) {
                          String errorMessage = 'Failed to send reset email. Please try again.';
                          
                          if (e is FirebaseAuthException) {
                            switch (e.code) {
                              case 'user-not-found':
                                errorMessage = 'Please sign up before logging in.';
                                break;
                              case 'invalid-email':
                                errorMessage = 'Invalid email format.';
                                break;
                              case 'too-many-requests':
                                errorMessage = 'Too many requests. Please try again later.';
                                break;
                              case 'network-request-failed':
                                errorMessage = 'Network error. Please check your connection and try again.';
                                break;
                              default:
                                errorMessage = 'Failed to send reset email. Please try again.';
                            }
                          } else {
                            // Handle non-Firebase exceptions
                            if (e.toString().contains('network') || e.toString().contains('connection')) {
                              errorMessage = 'Network error. Please check your connection and try again.';
                            } else if (e.toString().contains('timeout')) {
                              errorMessage = 'Request timed out. Please try again.';
                            } else {
                              errorMessage = 'Unexpected error occurred. Please try again.';
                            }
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessage)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Send Reset Email'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Helper widget to build text fields for Email/Password
  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData prefixIcon,
      bool isDark, {
        bool isPassword = false,
      }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        prefixIcon: Icon(prefixIcon),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        )
            : null,
        hintText: hint,
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final minButtonHeight = 48.0;
        final maxButtonHeight = 70.0;
        final buttonHeight = (height * 0.07).clamp(minButtonHeight, maxButtonHeight);
        final minLogoHeight = 48.0;
        final maxLogoHeight = 120.0;
        final logoHeight = (height * 0.08).clamp(minLogoHeight, maxLogoHeight);
        final horizontalPadding = (width * 0.06).clamp(16.0, 64.0);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: height - MediaQuery.of(context).padding.vertical),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/icons/auth_logo.png',
                                height: logoHeight,
                              ),
                              SizedBox(height: height * 0.04),
                              _buildTextField(_emailController, 'Email', Icons.email_outlined, isDark),
                              SizedBox(height: height * 0.02),
                              _buildTextField(_passwordController, 'Password', Icons.lock_outline, isDark, isPassword: true),
                              SizedBox(height: height * 0.02),
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: ElevatedButton(
                                  onPressed: isLogin ? _login : _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    isLogin ? 'Login' : 'Sign Up',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                              SizedBox(height: height * 0.02),
                              TextButton(
                                onPressed: () => setState(() => isLogin = !isLogin),
                                child: Text(
                                  isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login',
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                              if (isLogin) ...[
                                SizedBox(height: height * 0.01),
                                TextButton(
                                  onPressed: _showForgotPasswordSheet,
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: primaryColor),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
