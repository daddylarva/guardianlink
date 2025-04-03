import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String getChatId(String userId1, String userId2) {
    // 채팅방 ID를 일관되게 생성하기 위해 두 ID를 정렬하여 조합
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> sendMessage(String receiverId, String message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final chatId = getChatId(currentUser.uid, receiverId);
    final timestamp = FieldValue.serverTimestamp();

    // 메시지 저장
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'text': message,
      'timestamp': timestamp,
      'isRead': false,
    });

    // 채팅 목록 업데이트
    await Future.wait([
      // 보낸 사람의 채팅 목록 업데이트
      _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(receiverId)
          .set({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'unreadCount': 0,
        'userId': receiverId,
      }, SetOptions(merge: true)),

      // 받는 사람의 채팅 목록 업데이트
      _firestore
          .collection('users')
          .doc(receiverId)
          .collection('chats')
          .doc(currentUser.uid)
          .set({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'unreadCount': FieldValue.increment(1),
        'userId': currentUser.uid,
      }, SetOptions(merge: true)),
    ]);
  }

  Stream<List<Message>> getMessages(String userId, String otherUserId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(otherUserId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      return [Message.fromMap(snapshot.data()!, snapshot.id)];
    });
  }

  Future<void> markMessagesAsRead(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = getChatId(currentUser.uid, otherUserId);
    final batch = _firestore.batch();

    // 메시지를 읽음으로 표시
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: otherUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // 채팅 목록의 읽지 않은 메시지 수를 0으로 설정
    final chatRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(otherUserId);

    batch.update(chatRef, {'unreadCount': 0});
    await batch.commit();
  }

  Stream<int> getUnreadMessageCount(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(otherUserId)
        .snapshots()
        .map((doc) => doc.data()?['unreadCount'] ?? 0);
  }

  Stream<int> getTotalUnreadMessageCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc.data()['unreadCount'] ?? 0) as int,
      );
    });
  }

  Stream<QuerySnapshot> getChatList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<void> updateChatList(String otherUserId, String lastMessage) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    // 현재 사용자의 채팅 목록 업데이트
    final currentUserChatRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(otherUserId);

    batch.set(
      currentUserChatRef,
      {
        'userId': otherUserId,
        'lastMessage': lastMessage,
        'lastMessageTime': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    // 상대방의 채팅 목록 업데이트
    final otherUserChatRef = _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('chats')
        .doc(currentUser.uid);

    batch.set(
      otherUserChatRef,
      {
        'userId': currentUser.uid,
        'lastMessage': lastMessage,
        'lastMessageTime': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser.uid).update({
      'isOnline': isOnline,
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }
} 