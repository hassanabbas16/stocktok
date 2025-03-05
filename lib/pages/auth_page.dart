import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;

  void _login() async {
    setState(() => isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful!')),
      );
      _emailController.clear();
      _passwordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _signup() async {
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
      setState(() => isLogin = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We rely on Theme.of(context).scaffoldBackgroundColor now,
      // so remove backgroundColor override.
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                // Use the theme’s primaryColor or keep your own color
                backgroundColor: Theme.of(context).primaryColor,
                child: const Icon(Icons.trending_up, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'StockTok',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Email TextField
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Password TextField
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              // Primary Button (Login / Sign Up)
              ElevatedButton(
                onPressed: isLogin ? _login : _signup,
                style: ElevatedButton.styleFrom(
                  // Rely on theme for colors
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isLogin ? 'Login' : 'Sign Up',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => isLogin = !isLogin);
                },
                style: TextButton.styleFrom(
                  // Rely on theme for color
                  minimumSize: const Size.fromHeight(40),
                ),
                child: Text(
                  isLogin
                      ? 'Don’t have an account? Sign up'
                      : 'Already have an account? Login',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
