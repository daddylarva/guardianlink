import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BatteryService extends ChangeNotifier {
  final Battery _battery = Battery();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int? _batteryLevel;
  bool _isInitialized = false;

  int? get batteryLevel => _batteryLevel;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 현재 배터리 레벨 가져오기
      _batteryLevel = await _battery.batteryLevel;
      _isInitialized = true;
      notifyListeners();

      // 배터리 상태 변경 감지
      _battery.onBatteryStateChanged.listen((BatteryState state) async {
        _batteryLevel = await _battery.batteryLevel;
        _updateBatteryLevel();
        notifyListeners();
      });

      // 주기적으로 배터리 레벨 업데이트
      Future.doWhile(() async {
        await Future.delayed(const Duration(minutes: 1));
        _batteryLevel = await _battery.batteryLevel;
        _updateBatteryLevel();
        notifyListeners();
        return true;
      });
    } catch (e) {
      debugPrint('배터리 서비스 초기화 중 오류 발생: $e');
      rethrow;
    }
  }

  Future<void> _updateBatteryLevel() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'batteryLevel': _batteryLevel,
        'lastBatteryUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('배터리 레벨 업데이트 중 오류 발생: $e');
    }
  }

  Future<void> updateBatteryLevel() async {
    _batteryLevel = await _battery.batteryLevel;
    await _updateBatteryLevel();
    notifyListeners();
  }

  Stream<int?> getBatteryLevel(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['batteryLevel'] as int?);
  }
} 