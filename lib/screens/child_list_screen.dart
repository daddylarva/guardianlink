import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChildListScreen extends StatefulWidget {
  const ChildListScreen({super.key});

  @override
  State<ChildListScreen> createState() => _ChildListScreenState();
}

class _ChildListScreenState extends State<ChildListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _matchWithChild(String childId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // 자녀 정보 가져오기
      final childDoc = await _firestore.collection('users').doc(childId).get();
      if (!childDoc.exists) return;

      final childData = childDoc.data() as Map<String, dynamic>;
      final childName = childData['nickname'] ?? '알 수 없음';

      // 부모의 matched_children 컬렉션에 자녀 추가
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matched_children')
          .doc(childId)
          .set({
        'name': childName,
        'matchedAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });

      // 자녀의 matched_parents 컬렉션에 부모 추가
      await _firestore
          .collection('users')
          .doc(childId)
          .collection('matched_parents')
          .doc(currentUser.uid)
          .set({
        'name': currentUser.displayName ?? '부모',
        'matchedAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자녀와 매칭되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자녀 목록'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .where('role', isEqualTo: 'child')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = snapshot.data?.docs ?? [];

          if (children.isEmpty) {
            return const Center(
              child: Text('매칭 가능한 자녀가 없습니다.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              final childData = child.data() as Map<String, dynamic>;
              final childName = childData['nickname'] ?? '알 수 없음';
              final childId = child.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(childName),
                  subtitle: Text('ID: $childId'),
                  trailing: ElevatedButton(
                    onPressed: () => _matchWithChild(childId),
                    child: const Text('매칭'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 