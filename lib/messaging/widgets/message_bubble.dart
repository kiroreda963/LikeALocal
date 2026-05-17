import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../Models/place_model.dart';
import '../../Providers/PlaceProvider.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final Timestamp timestamp;
  final String? senderAvatar;
  final bool showAvatar;
  final String? placeId;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.senderAvatar,
    this.showAvatar = true,
    this.placeId,
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
                child: placeId != null
                    ? _buildPlaceCard(context, placeId!)
                    : Text(
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

  Widget _buildPlaceCard(BuildContext context, String id) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('places').doc(id).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 100,
            height: 50,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Text('Place not found');

        final name = data['placeName'] ?? 'Unknown';
        final category = data['category'] ?? '';
        final rating = (data['rating'] ?? 0.0).toDouble();

        return InkWell(
          onTap: () {
            final place = Place.fromMap(data, id);
            Provider.of<PlacesProvider>(context, listen: false).openPlaceOnMap(place);
            Navigator.popUntil(context, (route) => route.isFirst); // Go back to main shell
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMine ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                category,
                style: TextStyle(
                  fontSize: 12,
                  color: isMine ? Colors.white70 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  Text(
                    ' $rating',
                    style: TextStyle(
                      fontSize: 12,
                      color: isMine ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to view on map',
                style: TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ],
          ),
        );
      },
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
