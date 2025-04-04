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
  DateTime? _codeExpiryTime;
  static const int _codeValidityMinutes = 30; // 초대 코드 유효 시간 (분)
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
        final data = doc.data();
        if (data != null) {
          final code = data['inviteCode'] as String?;
          final generatedAt = data['inviteCodeGeneratedAt'] as Timestamp?;

          if (code != null && generatedAt != null) {
            final expiryTime = generatedAt.toDate().add(Duration(minutes: _codeValidityMinutes));
            if (expiryTime.isAfter(DateTime.now())) {
              setState(() {
                _inviteCode = code;
                _codeExpiryTime = expiryTime;
              });
              return;
            }
          }
        }
      }
      // 유효한 코드가 없으면 새로 생성
      await _generateInviteCode();
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
      final matchedChildren = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('matched_children')
          .get();

      if (matchedChildren.docs.isNotEmpty) {
        final childDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(matchedChildren.docs.first.id)
            .get();
        
        if (childDoc.exists) {
          setState(() {
            _matchedChildId = childDoc.id;
            _matchedChildName = childDoc.data()?['nickname'] as String?;
          });
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
      final now = DateTime.now();

      // Firestore에 초대 코드 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'inviteCode': code,
        'inviteCodeGeneratedAt': Timestamp.fromDate(now),
        'isParent': true,
      });

      setState(() {
        _inviteCode = code;
        _codeExpiryTime = now.add(Duration(minutes: _codeValidityMinutes));
      });
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

  String _formatRemainingTime() {
    if (_codeExpiryTime == null) return '';
    final now = DateTime.now();
    final remaining = _codeExpiryTime!.difference(now);
    if (remaining.isNegative) return '만료됨';
    return '${remaining.inMinutes}분 ${remaining.inSeconds % 60}초';
  }

  Future<void> _unmatchChild() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다.');

      // 자녀의 매칭 정보 제거
      if (_matchedChildId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_matchedChildId)
            .update({
          'guardianId': FieldValue.delete(),
          'matchedAt': FieldValue.delete(),
        });

        // 부모의 matched_children 서브컬렉션에서 자녀 정보 제거
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('matched_children')
            .doc(_matchedChildId)
            .delete();
      }

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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '초대 코드',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_inviteCode != null) ...[
                      Text(
                        _inviteCode!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '남은 시간: ${_formatRemainingTime()}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ] else if (_isLoading) ...[
                      const CircularProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateInviteCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('새로운 코드 생성'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '초대 코드 사용 방법',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. 자녀의 GuardianLink 앱에서 "보호자 연결" 메뉴 선택'),
                    SizedBox(height: 8),
                    Text('2. 위의 초대 코드를 입력'),
                    SizedBox(height: 8),
                    Text('3. 연결 완료!'),
                    SizedBox(height: 16),
                    Text(
                      '* 초대 코드는 30분간 유효하며, 한 번만 사용할 수 있습니다.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_matchedChildId != null) ...[
              const SizedBox(height: 24),
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