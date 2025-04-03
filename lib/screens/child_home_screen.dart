import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import 'child/child_pairing_screen.dart';
import 'chat/chat_list_screen.dart';
import '../services/battery_service.dart';
import '../widgets/unread_message_badge.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({Key? key}) : super(key: key);

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  String? _guardianId;
  final BatteryService _batteryService = BatteryService();

  @override
  void initState() {
    super.initState();
    _loadMatchedGuardian();
    _updateLastActive();
    _updateBatteryLevel();
  }

  Future<void> _updateLastActive() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 업데이트 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _updateOfflineStatus();
    super.dispose();
  }

  Future<void> _updateOfflineStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'isOnline': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 업데이트 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadMatchedGuardian() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _guardianId = userDoc.data()?['guardianId'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('보호자 정보를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _updateBatteryLevel() async {
    await _batteryService.updateBatteryLevel();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        title: const Text('GuardianLink'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
          ),
          StreamBuilder<int>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .where('receiverId', isEqualTo: user?.uid)
                .where('isRead', isEqualTo: false)
                .snapshots()
                .map((snapshot) => snapshot.docs.length),
            builder: (context, snapshot) {
              return UnreadMessageBadge(
                hasUnreadMessages: snapshot.hasData && snapshot.data! > 0,
                child: IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatListScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(context),
            const SizedBox(height: 32),
            const Text(
              '오늘의 활동',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              title: '할 일 확인하기',
              icon: Icons.checklist,
              color: Colors.blue,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '위치 전송하기',
              icon: Icons.location_on,
              color: Colors.green,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '긴급 알림',
              icon: Icons.warning,
              color: Colors.red,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '보호자 연결',
              icon: Icons.link,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChildPairingScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final nickname = userData?['nickname'] ?? '사용자';
        final email = user?.email ?? '';
        final photoUrl = user?.photoURL;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요 $nickname님!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatListScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 26,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}