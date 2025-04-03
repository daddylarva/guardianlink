import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'role_selection_screen.dart';
import 'parent_home_screen.dart';
import 'child_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = doc.data()?['role'];

        if (role == 'parent') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ParentHomeScreen()),
          );
        } else if (role == 'child') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChildHomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = '로그인 실패';
      if (e.code == 'user-not-found') {
        message = '등록되지 않은 이메일입니다.';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 틀렸습니다.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'GuardianLink',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('로그인', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
                child: const Text("아직 계정이 없으신가요? 회원가입"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}