import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  static final ChatService _chatService = ChatService();

  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getChatList(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!;
          
          if (chats.isEmpty) {
            return const Center(
              child: Text('아직 매칭된 사용자가 없습니다.'),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(chat['otherUserName'][0]),
                ),
                title: Text(chat['otherUserName']),
                subtitle: Text(
                  chat['lastMessage'] ?? '새로운 대화를 시작해보세요!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUserId: chat['otherUserId'],
                        otherUserName: chat['otherUserName'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 