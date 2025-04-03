import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChildPairingScreen extends StatefulWidget {
  const ChildPairingScreen({Key? key}) : super(key: key);

  @override
  State<ChildPairingScreen> createState() => _ChildPairingScreenState();
}

class _ChildPairingScreenState extends State<ChildPairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _matchedGuardianId;
  String? _matchedGuardianName;

  @override
  void initState() {
    super.initState();
    _loadMatchedGuardian();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchedGuardian() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final guardianId = doc.data()?['guardianId'] as String?;
        if (guardianId != null) {
          final guardianDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(guardianId)
              .get();
          
          if (guardianDoc.exists) {
            setState(() {
              _matchedGuardianId = guardianId;
              _matchedGuardianName = guardianDoc.data()?['nickname'] as String?;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭된 보호자 정보 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _pairWithGuardian() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다.');

      // 보호자 코드로 보호자 찾기
      final guardianQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('inviteCode', isEqualTo: _codeController.text)
          .where('role', isEqualTo: 'parent')
          .get();

      if (guardianQuery.docs.isEmpty) {
        throw Exception('유효하지 않은 초대 코드입니다.');
      }

      final guardianDoc = guardianQuery.docs.first;
      final guardianId = guardianDoc.id;

      // 이미 매칭된 보호자가 있는지 확인
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (childDoc.data()?['guardianId'] != null) {
        throw Exception('이미 보호자와 매칭되어 있습니다.');
      }

      // 매칭 정보 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'guardianId': guardianId,
        'matchedAt': FieldValue.serverTimestamp(),
      });

      // 보호자의 매칭 정보도 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(guardianId)
          .update({
        'childId': currentUser.uid,
        'matchedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보호자와 성공적으로 매칭되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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
            if (_matchedGuardianId != null) ...[
              const Text(
                '매칭된 보호자',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  _matchedGuardianName ?? '보호자',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const Text(
                '보호자의 초대 코드를 입력해주세요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: '초대 코드',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '초대 코드를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _pairWithGuardian,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('보호자와 연결하기'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}