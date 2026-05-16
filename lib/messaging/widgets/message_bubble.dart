import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final Timestamp timestamp;
  final String? senderAvatar;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.senderAvatar,
    this.showAvatar = true,
  });

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && showAvatar) ...[
            _buildSenderAvatar(),
            const SizedBox(width: 8),
          ] else if (!isMine) ...[
            const SizedBox(width: 40),
          ],
          Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMine ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatTime(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSenderAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: senderAvatar != null && senderAvatar!.isNotEmpty
          ? Image.network(senderAvatar!, fit: BoxFit.cover)
          : const Icon(Icons.smart_toy_outlined,
              color: Colors.white, size: 18),
    );
  }
}
