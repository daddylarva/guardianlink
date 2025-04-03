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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'child_location_screen.dart';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserProfileCard(_auth.currentUser!),
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
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(User currentUser) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final nickname = userData['nickname'] as String? ?? '사용자';
        final photoUrl = userData['photoUrl'] as String?;

        return Card(
          elevation: 4,
          margin: EdgeInsets.zero,
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
                  Colors.blue.shade400,
                  Colors.blue.shade800,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileEditScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? const Icon(Icons.person, size: 35, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '안녕하세요,',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$nickname님',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
        _buildMatchedChildrenList(currentUser),
      ],
    );
  }

  Widget _buildMatchedChildrenList(User currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matched_children')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final matchedChildren = snapshot.data!.docs;
        if (matchedChildren.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  '매칭된 자녀가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ParentPairingScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('자녀와 매칭하기'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matchedChildren.length,
          itemBuilder: (context, index) {
            final childDoc = matchedChildren[index];
            final childId = childDoc.id;
            final childData = childDoc.data() as Map<String, dynamic>;
            final isOnline = childData['isOnline'] ?? false;
            final lastSeen = childData['lastSeen'] as Timestamp?;

            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(childId).snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                final nickname = userData['nickname'] as String? ?? '이름 없음';
                final photoUrl = userData['photoUrl'] as String?;
                final batteryLevel = userData['batteryLevel'] as int? ?? 0;

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
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
                          Colors.purple.shade400,
                          Colors.purple.shade800,
                        ],
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          image: photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: photoUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              )
                            : StreamBuilder<DocumentSnapshot>(
                                stream: _firestore
                                    .collection('users')
                                    .doc(childId)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final isOnline = snapshot.data?.data()
                                          as Map<String, dynamic>? ??
                                      {'isOnline': false};
                                  if (isOnline['isOnline'] == true) {
                                    return Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.battery_std,
                                  color: _getBatteryColor(batteryLevel),
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$batteryLevel%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: _firestore.collection('users').doc(childId).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Text(
                                  '상태 확인 중...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                );
                              }

                              final userData = snapshot.data!.data() as Map<String, dynamic>?;
                              final isOnline = userData?['isOnline'] ?? false;
                              final lastSeen = userData?['lastSeen'] as Timestamp?;
                              final lastLocation = userData?['lastLocation'] as Map<String, dynamic>?;
                              final address = lastLocation?['address'] as String?;

                              // 위치 정보가 있으면 히스토리에 저장
                              if (lastLocation != null) {
                                _firestore
                                    .collection('users')
                                    .doc(childId)
                                    .collection('location_history')
                                    .add({
                                  'latitude': lastLocation['latitude'],
                                  'longitude': lastLocation['longitude'],
                                  'address': lastLocation['address'],
                                  'landmark': lastLocation['landmark'],
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                              }

                              String statusText;
                              if (isOnline) {
                                statusText = '온라인';
                              } else if (lastSeen != null) {
                                final now = DateTime.now();
                                final difference = now.difference(lastSeen.toDate());
                                if (difference.inMinutes < 1) {
                                  statusText = '방금 전';
                                } else if (difference.inHours < 1) {
                                  statusText = '${difference.inMinutes}분 전';
                                } else if (difference.inDays < 1) {
                                  statusText = '${difference.inHours}시간 전';
                                } else {
                                  statusText = '오프라인';
                                }
                              } else {
                                statusText = '오프라인';
                              }

                              return Row(
                                children: [
                                  Text(
                                    statusText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (address != null) ...[
                                    const SizedBox(width: 8),
                                    const Text(
                                      '•',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.location_on, color: Colors.white, size: 28),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChildLocationScreen(
                                        childId: childId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.checklist, color: Colors.white, size: 28),
                                onPressed: () {
                                  // 할일 관리 기능 구현
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        otherUserId: childId,
                                        otherUserName: nickname,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChildProfileScreen(
                              childId: childId,
                              nickname: nickname,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
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