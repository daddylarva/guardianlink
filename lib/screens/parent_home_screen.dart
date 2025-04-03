import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import 'parent/parent_pairing_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({Key? key}) : super(key: key);

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  String? _matchedChildId;
  String? _matchedChildName;
  String? _matchedChildPhotoUrl;
  bool? _isChildOnline;
  DateTime? _lastActive;

  @override
  void initState() {
    super.initState();
    _loadMatchedChild();
  }

  Future<void> _loadMatchedChild() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final childId = doc.data()?['childId'] as String?;
        if (childId != null) {
          final childDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(childId)
              .get();
          
          if (childDoc.exists) {
            final data = childDoc.data() as Map<String, dynamic>;
            setState(() {
              _matchedChildId = childId;
              _matchedChildName = data['nickname'] as String?;
              _matchedChildPhotoUrl = data['photoUrl'] as String?;
              _isChildOnline = data['isOnline'] as bool?;
              _lastActive = (data['lastActive'] as Timestamp?)?.toDate();
            });

            // 자녀의 상태 변경을 실시간으로 감지
            FirebaseFirestore.instance
                .collection('users')
                .doc(childId)
                .snapshots()
                .listen((snapshot) {
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>;
                setState(() {
                  _isChildOnline = data['isOnline'] as bool?;
                  _lastActive = (data['lastActive'] as Timestamp?)?.toDate();
                });
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('자녀 정보 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  String _getStatusText() {
    if (_isChildOnline == true) {
      return '온라인';
    } else if (_lastActive != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastActive!);
      
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else {
        return '${difference.inDays}일 전';
      }
    }
    return '오프라인';
  }

  Color _getStatusColor() {
    if (_isChildOnline == true) {
      return Colors.green;
    } else if (_lastActive != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastActive!);
      
      if (difference.inMinutes < 5) {
        return Colors.orange;
      }
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        title: const Text('GuardianLink'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6C63FF),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(context),
            if (_matchedChildId != null) ...[
              const SizedBox(height: 24),
              _buildMatchedChildCard(context),
            ],
            const SizedBox(height: 32),
            const Text(
              '자녀 관리',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              title: '자녀 위치 확인',
              icon: Icons.location_on,
              color: Colors.deepPurple,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '자녀 할 일 관리',
              icon: Icons.checklist,
              color: Colors.indigo,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '메시지 보내기',
              icon: Icons.message,
              color: Colors.teal,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '자녀 연결 설정',
              icon: Icons.link,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ParentPairingScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedChildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange[300]!, width: 2),
                ),
                child: ClipOval(
                  child: _matchedChildPhotoUrl != null
                      ? Image.network(
                          _matchedChildPhotoUrl!,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, size: 24, color: Colors.orange[300]);
                          },
                        )
                      : Icon(Icons.person, size: 24, color: Colors.orange[300]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _matchedChildName ?? '자녀',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: _getStatusColor(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.location_on, color: Colors.orange),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChildActionButton(
                icon: Icons.message,
                label: '메시지',
                onTap: () {},
              ),
              _buildChildActionButton(
                icon: Icons.checklist,
                label: '할 일',
                onTap: () {},
              ),
              _buildChildActionButton(
                icon: Icons.settings,
                label: '설정',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.orange, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final nickname = data?['nickname'] ?? '사용자';
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        final photoUrl = data?['photoUrl'];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person, size: 28, color: Colors.grey[400]);
                            },
                          )
                        : Icon(Icons.person, size: 28, color: Colors.grey[400]),
                  ),
                ),
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
            ],
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