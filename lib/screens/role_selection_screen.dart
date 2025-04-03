import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'parent_home_screen.dart';
import 'child_home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  Future<void> _selectRole(BuildContext context, String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'role': role,
    }, SetOptions(merge: true));

    if (role == 'parent') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ParentHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChildHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFFEDE7F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                '당신의 역할을 선택해주세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildRoleCard(
                context,
                title: '보호자',
                subtitle: '자녀의 위치를 확인하고 관리할 수 있습니다.',
                icon: Icons.family_restroom,
                color: Colors.deepPurple,
                role: 'parent',
              ),
              const SizedBox(height: 24),
              _buildRoleCard(
                context,
                title: '피보호자',
                subtitle: '보호자의 지시에 따라 위치를 전송합니다.',
                icon: Icons.child_care,
                color: Colors.green,
                role: 'child',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required String role,
      }) {
    return GestureDetector(
      onTap: () => _selectRole(context, role),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 30,
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}