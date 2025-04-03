import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 채팅방 ID 생성
  String _getChatRoomId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '${userId1}_${userId2}'
        : '${userId2}_${userId1}';
  }

  // 메시지 전송
  Future<void> sendMessage(String receiverId, String content) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final chatRoomId = _getChatRoomId(currentUser.uid, receiverId);
    final timestamp = FieldValue.serverTimestamp();

    // 메시지 저장
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'content': content,
      'timestamp': timestamp,
    });

    // 채팅방 정보 업데이트
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': content,
      'lastMessageTime': timestamp,
      'participants': [currentUser.uid, receiverId],
    }, SetOptions(merge: true));
  }

  // 메시지 목록 가져오기
  Stream<List<Message>> getMessages(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 채팅 목록 가져오기
  Stream<List<Map<String, dynamic>>> getChatList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> chats = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final otherUserId = (data['participants'] as List)
            .firstWhere((id) => id != currentUser.uid);
            
        // 상대방 정보 가져오기
        final userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();
            
        if (userDoc.exists) {
          chats.add({
            'otherUserId': otherUserId,
            'otherUserName': userDoc.data()?['name'] ?? '알 수 없음',
            'lastMessage': data['lastMessage'],
            'lastMessageTime': data['lastMessageTime'],
          });
        }
      }
      
      return chats;
    });
  }

  // 메시지 읽음 표시
  Future<void> markAsRead(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({
      'isRead': true,
    });
  }

  // 읽지 않은 메시지 수 가져오기
  Stream<int> getUnreadMessageCount(String otherUserId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('senderId', isEqualTo: otherUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
} 