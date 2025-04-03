import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ParentPairingScreen extends StatefulWidget {
  const ParentPairingScreen({Key? key}) : super(key: key);

  @override
  State<ParentPairingScreen> createState() => _ParentPairingScreenState();
}

class _ParentPairingScreenState extends State<ParentPairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _inviteCode;
  String? _matchedChildId;
  String? _matchedChildName;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
    _loadMatchedChild();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadInviteCode() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _inviteCode = doc.data()?['inviteCode'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 코드 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
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
            setState(() {
              _matchedChildId = childId;
              _matchedChildName = childDoc.data()?['nickname'] as String?;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭된 자녀 정보 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _generateInviteCode() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다.');

      // 6자리 랜덤 코드 생성
      final random = Random();
      final code = List.generate(6, (_) => random.nextInt(10)).join();

      // Firestore에 초대 코드 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'inviteCode': code,
        'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _inviteCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 코드 생성 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unmatchChild() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다.');

      // 자녀의 매칭 정보도 함께 제거
      if (_matchedChildId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_matchedChildId)
            .update({
          'guardianId': FieldValue.delete(),
          'matchedAt': FieldValue.delete(),
        });
      }

      // 부모의 매칭 정보 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'childId': FieldValue.delete(),
        'matchedAt': FieldValue.delete(),
      });

      setState(() {
        _matchedChildId = null;
        _matchedChildName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자녀와의 매칭이 해제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭 해제 중 오류가 발생했습니다: $e')),
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
        title: const Text('자녀 연결'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '나의 초대 코드',
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _inviteCode ?? '초대 코드가 없습니다',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (_inviteCode == null)
              ElevatedButton(
                onPressed: _isLoading ? null : _generateInviteCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('초대 코드 생성하기'),
              ),
            const SizedBox(height: 32),
            if (_matchedChildId != null) ...[
              const Text(
                '매칭된 자녀',
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
                child: Column(
                  children: [
                    Text(
                      _matchedChildName ?? '자녀',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _unmatchChild,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[700],
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('매칭 해제'),
                    ),
                  ],
                ),
              ),
            ] else
              const Text(
                '아직 매칭된 자녀가 없습니다.\n자녀가 초대 코드를 입력하여 연결해주세요.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}