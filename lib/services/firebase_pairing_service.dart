import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebasePairingService {
  static final _firestore = FirebaseFirestore.instance;

  /// 6자리 숫자 코드 생성
  static String _generateCode() {
    final rand = Random();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  /// 부모: 매칭 코드 생성
  static Future<String> createPairingCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("로그인 필요");

    String code = _generateCode();
    final docRef = _firestore.collection('matching_codes').doc(code);

    await docRef.set({
      'parentUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  /// 자녀: 코드 입력 → 매칭 처리
  static Future<void> matchWithCode(String code) async {
    final childUid = FirebaseAuth.instance.currentUser?.uid;
    if (childUid == null) throw Exception("로그인 필요");

    final doc = await _firestore.collection('matching_codes').doc(code).get();
    if (!doc.exists) throw Exception("잘못된 코드입니다.");

    final parentUid = doc['parentUid'];

    // 부모 - 자녀 상호 저장
    await _firestore.collection('users').doc(parentUid).set({
      'pairedChildId': childUid,
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(childUid).set({
      'pairedParentId': parentUid,
    }, SetOptions(merge: true));
  }

  /// 부모: 연결된 자녀 UID 가져오기
  static Future<String?> getPairedChildId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['pairedChildId'];
  }

  /// 자녀: 연결된 부모 UID 가져오기
  static Future<String?> getPairedParentId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['pairedParentId'];
  }
}