import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String get _chatId => widget.chatId.trim();

  // Cache for other party info
  String? _otherPartyName;
  String? _serviceTitle;

  String _chatErrorMessage(Object error) {
    if (error is FirebaseException && error.code == 'failed-precondition') {
      return 'Chat index/config is missing. Please deploy Firestore indexes and retry.';
    }
    return FirestoreErrorHandler.toUserMessage(error);
  }

  @override
  void initState() {
    super.initState();
    _loadChatMetadata();
  }

  Future<void> _loadChatMetadata() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _chatId.isEmpty) return;

    try {
      final bookingDoc = await FirestoreRefs.bookings().doc(_chatId).get();
      final bookingData = bookingDoc.data();
      if (bookingData == null) return;

      final providerId = bookingData['providerId']?.toString() ?? '';
      final seekerId = bookingData['seekerId']?.toString() ?? '';
      final serviceId = bookingData['serviceId']?.toString() ?? '';
      final otherPartyId = user.uid == providerId ? seekerId : providerId;

      if (otherPartyId.isNotEmpty) {
        final userDoc = await FirestoreRefs.users().doc(otherPartyId).get();
        final userData = userDoc.data();
        if (userData != null && mounted) {
          setState(() {
            _otherPartyName =
                userData['displayName']?.toString() ??
                userData['name']?.toString() ??
                'User';
          });
        }
      }

      if (serviceId.isNotEmpty) {
        final serviceDoc = await FirestoreRefs.services().doc(serviceId).get();
        final serviceData = serviceDoc.data();
        if (serviceData != null && mounted) {
          setState(
            () => _serviceTitle = serviceData['title']?.toString() ?? 'Service',
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_chatId.isEmpty) {
      FirestoreErrorHandler.showError(context, 'Invalid chat session.');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message cannot be empty.')));
      return;
    }
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is too long (max 500 chars).')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await FirestoreRefs.messages().add({
        'chatId': _chatId,
        'senderId': user.uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      _scrollToBottom();
    } on FirebaseException catch (e) {
      if (mounted) {
        FirestoreErrorHandler.showError(context, _chatErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        FirestoreErrorHandler.showError(context, _chatErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);

    if (messageDay == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (today.difference(messageDay).inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(dt)}';
    } else if (today.difference(messageDay).inDays < 7) {
      return DateFormat('EEE h:mm a').format(dt);
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  bool _shouldShowDateHeader(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) {
    if (index == 0) return true;
    final curr = docs[index].data()['createdAt'] as Timestamp?;
    final prev = docs[index - 1].data()['createdAt'] as Timestamp?;
    if (curr == null || prev == null) return false;
    final currDate = curr.toDate();
    final prevDate = prev.toDate();
    return currDate.year != prevDate.year ||
        currDate.month != prevDate.month ||
        currDate.day != prevDate.day;
  }

  String _dateHeaderText(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);

    if (messageDay == today) return 'Today';
    if (today.difference(messageDay).inDays == 1) return 'Yesterday';
    if (today.difference(messageDay).inDays < 7) {
      return DateFormat('EEEE').format(dt);
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Chat',
          subtitle: 'Send and receive booking messages in real time.',
          useScaffold: true,
          child: Center(child: Text('Not signed in')),
        );
      }
      return const MobilePageScaffold(
        title: 'Chat',
        subtitle: 'Send and receive booking messages in real time.',
        accentColor: MobileTokens.primary,
        useScaffold: true,
        body: Center(child: Text('Not signed in')),
      );
    }
    if (_chatId.isEmpty) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Chat',
          subtitle: 'Send and receive booking messages in real time.',
          useScaffold: true,
          child: Center(
            child: Text(
              'Invalid chat reference. Open chat again from bookings.',
            ),
          ),
        );
      }
      return const MobilePageScaffold(
        title: 'Chat',
        subtitle: 'Send and receive booking messages in real time.',
        accentColor: MobileTokens.primary,
        useScaffold: true,
        body: Center(
          child: Text('Invalid chat reference. Open chat again from bookings.'),
        ),
      );
    }

    final chatBgColor = isDark
        ? const Color(0xFF0B141A)
        : const Color(0xFFE5DDD5);
    final inputBgColor = isDark
        ? const Color(0xFF1F2C34)
        : const Color(0xFFF0F0F0);
    final inputFieldColor = isDark ? const Color(0xFF2A3942) : Colors.white;
    final headerColor = isDark ? const Color(0xFF1F2C34) : MobileTokens.primary;
    final otherPartyName = _otherPartyName?.trim() ?? '';
    final otherPartyInitial = otherPartyName.isNotEmpty
        ? otherPartyName[0].toUpperCase()
        : 'U';

    final body = Container(
      color: chatBgColor,
      child: Column(
        children: [
          // Chat header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 18,
                    child: Text(
                      otherPartyInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otherPartyName ?? 'Chat',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (_serviceTitle != null)
                          Text(
                            _serviceTitle!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Messages area
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreRefs.messages()
                  .where('chatId', isEqualTo: _chatId)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_chatErrorMessage(snapshot.error!)),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No messages yet. Say hello!',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                // Auto-scroll to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMine = data['senderId'] == user.uid;
                    final text = data['text'] ?? '';
                    final timestamp = data['createdAt'] as Timestamp?;
                    final timeStr = _formatTimestamp(timestamp);
                    final showDateHeader = _shouldShowDateHeader(docs, index);

                    return Column(
                      children: [
                        if (showDateHeader && timestamp != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF233040)
                                      : const Color(0xFFD9ECFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _dateHeaderText(timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF4A6C8C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _ChatBubble(
                          text: text,
                          time: timeStr,
                          isMine: isMine,
                          senderName: isMine
                              ? null
                              : (_otherPartyName ?? 'User'),
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Message input area
          Container(
            color: inputBgColor,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputFieldColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLength: 500,
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sending ? null : _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: const Color(0xFF128C7E),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sending ? null : _sendMessage,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (kIsWeb) {
      return WebPageScaffold(
        title: _serviceTitle ?? 'Chat',
        subtitle: 'Send and receive booking messages in real time.',
        useScaffold: true,
        child: body,
      );
    }

    return Scaffold(body: body);
  }
}

/// WhatsApp-style chat bubble widget
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.time,
    required this.isMine,
    this.senderName,
    this.isDark = false,
  });

  final String text;
  final String time;
  final bool isMine;
  final String? senderName;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF1F2C34) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF303030);
    final timeColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    final crossAlignment = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final rowAlignment = isMine
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
    final margin = isMine
        ? const EdgeInsets.only(left: 64, right: 4, top: 2, bottom: 2)
        : const EdgeInsets.only(right: 64, left: 4, top: 2, bottom: 2);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMine ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMine ? Radius.zero : const Radius.circular(12),
    );

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.76;

    return Container(
      margin: margin,
      child: Row(
        mainAxisAlignment: rowAlignment,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Column(
              crossAxisAlignment: crossAlignment,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (senderName != null && !isMine)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            senderName!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF53BDEB)
                                  : const Color(0xFF075E54),
                            ),
                          ),
                        ),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor,
                          height: 1.3,
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            time,
                            style: TextStyle(fontSize: 11, color: timeColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
