import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BatteryService {
  final Battery _battery = Battery();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      final user = _auth.currentUser;
      
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'batteryLevel': batteryLevel,
          'lastBatteryUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('배터리 정보 업데이트 실패: $e');
    }
  }

  Stream<int?> getBatteryLevel(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['batteryLevel'] as int?);
  }
} 