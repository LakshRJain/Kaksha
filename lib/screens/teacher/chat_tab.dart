import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:classcare/widgets/Colors.dart';

class ChatTab extends StatefulWidget {
  final String classId;
  const ChatTab({super.key, required this.classId});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String senderId = _auth.currentUser!.uid;

      // Fetch sender's name from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(senderId).get();
      String senderName = userDoc.exists ? userDoc['name'] : 'Unknown';
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('chats')
          .add({
        'senderId': _auth.currentUser!.uid,
        'senderName': senderName,
        'message': _messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Chat messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('classes')
                    .doc(widget.classId)
                    .collection('chats')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentBlue,
                      ),
                    );
                  }
                  var messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.secondaryText.withOpacity(0.5),
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No messages yet",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Start the conversation!",
                            style: TextStyle(
                              color: AppColors.tertiaryText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Show latest message at the bottom
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var message = messages[index];
                      String currentSenderId = message['senderId'] ?? '';
                      bool isMe = currentSenderId == _auth.currentUser!.uid;

                      // Get sender name with fallback
                      String senderName = message['senderName'] ?? 'Unknown';

                      // Check if this is the first message or a different sender than the previous message
                      bool showSenderName = true;
                      if (index < messages.length - 1) {
                        var previousMessage = messages[index + 1];
                        String previousSenderId =
                            previousMessage['senderId'] ?? '';
                        // Only show name if this is a different sender from the previous message
                        // (Remember the list is in reverse order due to 'reverse: true')
                        if (currentSenderId == previousSenderId) {
                          showSenderName = false;
                        }
                      }

                      return ChatBubble(
                        senderName: senderName,
                        message: message['message'],
                        isMe: isMe,
                        showSenderName: showSenderName,
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Message input area
          Container(
            margin: EdgeInsets.only(top: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.accentBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      color: AppColors.primaryText,
                    ),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(
                        color: AppColors.tertiaryText,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send_rounded, size: 20),
                    color: Colors.white,
                    onPressed: sendMessage,
                    tooltip: "Send message",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String senderName;
  final bool showSenderName;

  const ChatBubble({
    super.key,
    required this.senderName,
    required this.message,
    required this.isMe,
    this.showSenderName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Only show the sender name if showSenderName is true
          if (showSenderName)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 12,
                right: isMe ? 12 : 0,
                top: 8,
                bottom: 2,
              ),
              child: Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: isMe ? AppColors.accentBlue : AppColors.accentGreen,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: EdgeInsets.only(
              bottom: 4,
              left: isMe ? 40 : 8,
              right: isMe ? 8 : 40,
              top: showSenderName ? 2 : 2,
            ),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: isMe
                  ? AppColors.accentBlue.withOpacity(0.8)
                  : AppColors.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: isMe
                  ? null
                  : Border.all(
                      color: AppColors.surfaceColor,
                      width: 1,
                    ),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.primaryText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
