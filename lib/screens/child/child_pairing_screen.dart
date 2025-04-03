import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ChildPairingScreen extends StatefulWidget {
  const ChildPairingScreen({Key? key}) : super(key: key);

  @override
  State<ChildPairingScreen> createState() => _ChildPairingScreenState();
}

class _ChildPairingScreenState extends State<ChildPairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, String>> _matchedGuardians = [];

  @override
  void initState() {
    super.initState();
    _loadMatchedGuardians();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchedGuardians() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final guardiansSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('guardians')
          .get();

      final guardians = await Future.wait(
        guardiansSnapshot.docs.map((doc) async {
          return {
            'id': doc.id,
            'nickname': doc.data()['nickname'] as String? ?? '이름 없음',
          };
        }),
      );

      setState(() {
        _matchedGuardians = guardians;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭된 보호자 정보 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _pairWithParent(String code) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다.');

      // 이미 매칭된 보호자가 있는지 확인
      final existingGuardians = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('guardians')
          .get();

      if (existingGuardians.docs.isNotEmpty) {
        throw Exception('이미 다른 보호자와 매칭되어 있습니다. 한 명의 보호자만 매칭할 수 있습니다.');
      }

      // 초대 코드로 부모 찾기
      final parentQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('inviteCode', isEqualTo: code)
          .where('isParent', isEqualTo: true)
          .get();

      if (parentQuery.docs.isEmpty) {
        throw Exception('유효하지 않은 초대 코드입니다. 코드를 다시 확인해주세요.');
      }

      final parentDoc = parentQuery.docs.first;
      final parentId = parentDoc.id;
      final generatedAt = parentDoc.data()['inviteCodeGeneratedAt'] as Timestamp?;

      // 초대 코드의 유효 기간 확인
      if (generatedAt != null) {
        final expiryTime = generatedAt.toDate().add(const Duration(minutes: 30));
        if (expiryTime.isBefore(DateTime.now())) {
          throw Exception('초대 코드가 만료되었습니다. 보호자에게 새로운 코드를 요청해주세요.');
        }
      }

      // 새로운 초대 코드 생성
      final random = Random();
      final newCode = List.generate(6, (_) => random.nextInt(10)).join();

      // 부모의 초대 코드 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentId)
          .update({
        'inviteCode': newCode,
        'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
      });

      // 자녀의 guardians 서브컬렉션에 부모 정보 추가
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('guardians')
          .doc(parentId)
          .set({
        'nickname': parentDoc.data()?['nickname'] ?? '이름 없음',
        'matchedAt': FieldValue.serverTimestamp(),
      });

      // 자녀의 guardianId 필드 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'guardianId': parentId,
      });

      // 부모의 matched_children 서브컬렉션에 자녀 정보 추가
      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentId)
          .collection('matched_children')
          .doc(currentUser.uid)
          .set({
        'nickname': currentUser.displayName ?? '이름 없음',
        'matchedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('부모님과 연결되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('매칭 중 오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보호자 연결'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_matchedGuardians.isNotEmpty) ...[
              const Text(
                '매칭된 보호자',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _matchedGuardians.length,
                itemBuilder: (context, index) {
                  final guardian = _matchedGuardians[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            guardian['nickname']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red,
                          onPressed: () => _removeGuardian(guardian['id']!),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
            ],
            const Text(
              '새로운 보호자 연결',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '초대 코드',
                  hintText: '보호자의 초대 코드를 입력하세요',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '초대 코드를 입력해주세요';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _pairWithParent(_codeController.text);
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('연결하기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeGuardian(String guardianId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 자녀의 guardians 컬렉션에서 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('guardians')
          .doc(guardianId)
          .delete();

      // 자녀의 guardianId 필드 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'guardianId': FieldValue.delete(),
      });

      // 부모의 matched_children 컬렉션에서 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(guardianId)
          .collection('matched_children')
          .doc(currentUser.uid)
          .delete();

      // UI 업데이트
      setState(() {
        _matchedGuardians.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보호자와의 연결이 해제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 해제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
}