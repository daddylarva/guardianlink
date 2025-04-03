import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat/chat_screen.dart';
import '../services/location_service.dart';
import '../services/battery_service.dart';

class ChildProfileScreen extends StatefulWidget {
  final String childId;
  final String nickname;

  const ChildProfileScreen({
    Key? key,
    required this.childId,
    required this.nickname,
  }) : super(key: key);

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _unmatchChild() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // 부모의 matched_children 컬렉션에서 자녀 제거
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matched_children')
          .doc(widget.childId)
          .delete();

      // 자녀의 matched_parents 컬렉션에서 부모 제거
      await _firestore
          .collection('users')
          .doc(widget.childId)
          .collection('matched_parents')
          .doc(currentUser.uid)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자녀와 매칭이 해제되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭 해제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.childId),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(widget.childId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final childData = snapshot.data?.data() as Map<String, dynamic>?;
          final lastLocation = childData?['lastLocation'] as Map<String, dynamic>?;
          final batteryLevel = childData?['batteryLevel'] as int?;
          final isOnline = childData?['isOnline'] as bool? ?? false;
          final lastActive = childData?['lastActive'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? '온라인' : '오프라인',
                              style: TextStyle(
                                color: isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastLocation != null
                                    ? '위치: ${lastLocation['address'] ?? '알 수 없음'}'
                                    : '위치 정보 없음',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.battery_std, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              batteryLevel != null
                                  ? '배터리: $batteryLevel%'
                                  : '배터리 정보 없음',
                            ),
                          ],
                        ),
                        if (lastActive != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '마지막 활동: ${_formatLastActive(lastActive)}',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId: widget.childId,
                              otherUserName: widget.childId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('메시지 보내기'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _unmatchChild,
                      icon: const Icon(Icons.link_off),
                      label: const Text('매칭 해제'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatLastActive(Timestamp timestamp) {
    final now = DateTime.now();
    final lastActive = timestamp.toDate();
    final difference = now.difference(lastActive);

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
} 