import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필드를 입력해주세요.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 성공! 로그인 해주세요.')),
      );
      Navigator.pop(context); // 로그인 화면으로 되돌아가기
    } on FirebaseAuthException catch (e) {
      String message = '회원가입 실패';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'weak-password') {
        message = '비밀번호가 너무 약합니다.';
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
      appBar: AppBar(
        title: const Text('GuardianLink 회원가입'),
        backgroundColor: const Color(0xFF6C63FF),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const SizedBox(height: 32),
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
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _signup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('회원가입', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}