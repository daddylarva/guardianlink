import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/unread_message_badge.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import 'parent/parent_pairing_screen.dart';
import 'chat/chat_list_screen.dart';
import 'chat/chat_screen.dart';
import 'child_profile_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userPhotoUrl;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _updateOnlineStatus();
    _migrateMatchedChildren();
  }

  @override
  void dispose() {
    _updateOfflineStatus();
    super.dispose();
  }

  Future<void> _updateOnlineStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
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

  Future<void> _migrateMatchedChildren() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 기존 매칭 데이터 확인
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data();
      if (data == null) return;

      // 기존 childId 필드가 있는지 확인
      final childId = data['childId'] as String?;
      if (childId == null) return;

      // 이미 matched_children에 있는지 확인
      final matchedChildDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matched_children')
          .doc(childId)
          .get();

      if (matchedChildDoc.exists) return;

      // 자녀 정보 가져오기
      final childDoc = await _firestore
          .collection('users')
          .doc(childId)
          .get();

      if (!childDoc.exists) return;

      final childData = childDoc.data();
      if (childData == null) return;

      // matched_children 서브컬렉션에 자녀 정보 추가
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matched_children')
          .doc(childId)
          .set({
        'nickname': childData['nickname'] ?? '이름 없음',
        'matchedAt': childData['matchedAt'] ?? FieldValue.serverTimestamp(),
      });

      // 기존 childId 필드 삭제
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'childId': FieldValue.delete(),
      });

    } catch (e) {
      print('매칭 데이터 마이그레이션 중 오류 발생: $e');
    }
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
          StreamBuilder<int>(
            stream: ChatService().getTotalUnreadMessageCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return UnreadMessageBadge(
                count: unreadCount,
                child: IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatListScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
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
            _buildUserCard(),
            const SizedBox(height: 32),
            _buildMatchedChildrenSection(),
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
              title: '자녀 위치 확인',
              icon: Icons.location_on,
              color: Colors.blue,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: '할 일 관리',
              icon: Icons.checklist,
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
              title: '자녀 연결',
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

  Widget _buildUserCard() {
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
        final photoUrl = data?['photoUrl'];

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : const AssetImage('assets/images/default_avatar.png')
                                as ImageProvider,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '안녕하세요, $nickname님',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '오늘도 좋은 하루 되세요!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchedChildrenSection() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '매칭된 자녀',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('자녀 추가'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ParentPairingScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('matched_children')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('오류가 발생했습니다'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '아직 매칭된 자녀가 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('자녀 추가하기'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ParentPairingScreen()),
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 280.0 * snapshot.data!.docs.length,  // 각 카드의 예상 높이
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final childDoc = snapshot.data!.docs[index];
                  final childId = childDoc.id;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('users').doc(childId).snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()));
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (userData == null) {
                        return const SizedBox.shrink();
                      }

                      final nickname = userData['nickname'] as String? ?? '이름 없음';
                      final photoUrl = userData['photoUrl'] as String?;
                      final isOnline = userData['isOnline'] as bool? ?? false;
                      final lastSeen = userData['lastSeen'] as Timestamp?;
                      final batteryLevel = userData['batteryLevel'] as int? ?? 0;
                      final location = userData['location'] as Map<String, dynamic>?;

                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).primaryColor.withOpacity(0.7),
                                  Theme.of(context).primaryColor.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Stack(
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
                                          if (isOnline)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 15,
                                                height: 15,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nickname,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isOnline
                                                  ? '온라인'
                                                  : lastSeen != null
                                                      ? '마지막 접속: ${_formatLastSeen(lastSeen)}'
                                                      : '오프라인',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isOnline
                                                    ? Colors.green[100]
                                                    : Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildInfoCard(
                                        icon: Icons.battery_full,
                                        title: '배터리',
                                        value: '$batteryLevel%',
                                        color: _getBatteryColor(batteryLevel),
                                      ),
                                      if (location != null) ...[
                                        _buildInfoCard(
                                          icon: Icons.location_on,
                                          title: '위치',
                                          value: '${location['address'] ?? '알 수 없음'}',
                                          color: Colors.white,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.message,
                                        label: '메시지',
                                        onTap: () => _navigateToChatScreen(
                                          context,
                                          childId,
                                          nickname,
                                        ),
                                      ),
                                      _buildActionButton(
                                        icon: Icons.person,
                                        label: '프로필',
                                        onTap: () => _navigateToChildProfile(
                                          context,
                                          childId,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
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

  String _formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return '알 수 없음';
    final difference = DateTime.now().difference(lastSeen.toDate());
    if (difference.inMinutes < 1) {
      return '방금 전까지 온라인';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전까지 온라인';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전까지 온라인';
    } else {
      return '오프라인';
    }
  }

  Color _getBatteryColor(int level) {
    if (level < 20) {
      return Colors.red;
    } else if (level < 50) {
      return Colors.orange;
    } else if (level < 80) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  void _navigateToChatScreen(BuildContext context, String childId, String nickname) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: childId,
          otherUserName: nickname,
        ),
      ),
    );
  }

  void _navigateToChildProfile(BuildContext context, String childId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildProfileScreen(
          childId: childId,
          nickname: '',
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}