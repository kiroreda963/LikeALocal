import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../Models/user_model.dart' as local_user;
import '../../messaging/pages/chat_screen.dart';
import '../../Models/conversation_model.dart';

class FriendsGroupsPage extends StatefulWidget {
  const FriendsGroupsPage({super.key});

  @override
  State<FriendsGroupsPage> createState() => _FriendsGroupsPageState();
}

class _FriendsGroupsPageState extends State<FriendsGroupsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<local_user.User> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Friends & Groups',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF143C23),
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        _buildSearchBar(),
        if (_isSearching)
          Expanded(child: _buildSearchResultsList())
        else ...[
          // Pending Requests Section
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friend_requests')
                .where('receiverId', isEqualTo: currentUser.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox();
              }
              final requests = snapshot.data!.docs;

              return Container(
                color: Colors.amber.shade50,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Requests',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    const SizedBox(height: 8),
                    ...requests.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final senderId = data['senderId'];
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(senderId)
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox();
                          final userData = userSnap.data!.data() as Map<String, dynamic>?;
                          final name = userData?['name'] ?? 'User';

                          return ListTile(
                            title: Text(name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _acceptFriendRequest(doc.id, senderId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.red),
                                  onPressed: () => _rejectFriendRequest(doc.id),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
          
          // Friends List Section
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final friends = List<String>.from(userData?['friends'] ?? []);

                if (friends.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.people_outline,
                    title: 'No friends yet',
                    subtitle: 'Search for friends above to connect and share places!',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(friends[index])
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        final data = userSnap.data!.data() as Map<String, dynamic>?;
                        if (data == null) return const SizedBox();

                        return _buildUserTile(
                          name: data['name'] ?? 'User',
                          email: data['email'] ?? '',
                          photoUrl: data['photoUrl'],
                          onTap: () {
                            _openChat(friends[index], data['name'] ?? 'User');
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupsTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create New Group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF143C23),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participants', arrayContains: currentUser.uid)
                .where('isAI', isEqualTo: false) // Filter out AI
                // We need a way to identify groups. Let's use isGroup field!
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              // Filter for groups in memory if isGroup field is missing, or just assume conversations with > 2 participants or specific flag.
              final groups = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isGroup'] == true;
              }).toList();

              if (groups.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.group_outlined,
                  title: 'No groups yet',
                  subtitle: 'Create a group to plan trips and share places with friends!',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final data = groups[index].data() as Map<String, dynamic>;
                  return _buildGroupTile(
                    name: data['participantName'] ?? 'Group', // Reuse field or use groupName
                    memberCount: (data['participants'] as List).length,
                    onTap: () {
                      final conversation = ConversationModel.fromDoc(groups[index], currentUser.uid);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversation: conversation,
                            currentUserId: currentUser.uid,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by email or name...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          if (value.trim().isNotEmpty) {
            _searchUsers(value.trim());
          } else {
            setState(() {
              _isSearching = false;
              _searchResults = [];
            });
          }
        },
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isSearching = true);
    
    // Search by email or name
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    final users = snapshot.docs
        .map((doc) => local_user.User.fromMap(doc.data(), doc.id))
        .where((user) => user.uid != FirebaseAuth.instance.currentUser?.uid) // Exclude self
        .toList();

    setState(() {
      _searchResults = users;
    });
  }

  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(
          name: user.name,
          email: user.email,
          photoUrl: user.photoUrl,
          trailing: IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF143C23)),
            onPressed: () => _sendFriendRequest(user.uid),
          ),
        );
      },
    );
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Check if already friends
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
    if (friends.contains(targetUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already friends!')),
      );
      return;
    }

    // Check if request pending
    final existing = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('receiverId', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request already pending!')),
      );
      return;
    }
    
    await FirebaseFirestore.instance.collection('friend_requests').add({
      'senderId': currentUser.uid,
      'receiverId': targetUserId,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request sent!')),
    );
  }

  Future<void> _acceptFriendRequest(String requestId, String senderId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();
    
    // Update request status
    batch.update(FirebaseFirestore.instance.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
    });

    // Add to current user's friends
    batch.update(FirebaseFirestore.instance.collection('users').doc(currentUser.uid), {
      'friends': FieldValue.arrayUnion([senderId]),
    });

    // Add to sender's friends
    batch.update(FirebaseFirestore.instance.collection('users').doc(senderId), {
      'friends': FieldValue.arrayUnion([currentUser.uid]),
    });

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request accepted!')),
    );
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request rejected.')),
    );
  }

  Widget _buildUserTile({
    required String name,
    required String email,
    String? photoUrl,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }

  Widget _buildGroupTile({
    required String name,
    required int memberCount,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF143C23).withOpacity(0.1),
          child: const Icon(Icons.group, color: Color(0xFF143C23)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$memberCount members', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final isPremium = userDoc.data()?['isPremium'] ?? false;

    if (!isPremium) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upgrade to Pro'),
            content: const Text('Creating groups is a Pro feature. Upgrade to Pro to create groups!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final nameController = TextEditingController();
    final List<String> selectedFriends = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return const SizedBox();

            return AlertDialog(
              title: const Text('Create Group'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'Group Name'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Friends', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final userData = snapshot.data!.data() as Map<String, dynamic>?;
                          final friends = List<String>.from(userData?['friends'] ?? []);

                          if (friends.isEmpty) {
                            return const Text('No friends to add. Add friends first!');
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              final friendId = friends[index];
                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(friendId)
                                    .get(),
                                builder: (context, userSnap) {
                                  if (!userSnap.hasData) return const SizedBox();
                                  final data = userSnap.data!.data() as Map<String, dynamic>?;
                                  final name = data?['name'] ?? 'User';

                                  return CheckboxListTile(
                                    title: Text(name),
                                    value: selectedFriends.contains(friendId),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedFriends.add(friendId);
                                        } else {
                                          selectedFriends.remove(friendId);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      _createGroup(nameController.text.trim(), selectedFriends);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup(String groupName, List<String> memberIds) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final participants = [currentUser.uid, ...memberIds];

    await FirebaseFirestore.instance.collection('conversations').add({
      'isGroup': true,
      'isAI': false,
      'participantName': groupName,
      'participants': participants,
      'lastMessage': 'Group created',
      'lastMessageTime': Timestamp.now(),
      'creatorId': currentUser.uid,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group created!')),
    );
  }

  void _openChat(String otherUserId, String otherUserName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Use MessagingService to create or get conversation
    // Wait, we need MessagingService instance.
    // Let's just navigate to ChatScreen with conversationId if we can generate it.
    final sortedIds = [currentUser.uid, otherUserId]..sort();
    final conversationId = 'chat_${sortedIds.join('_')}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          currentUserId: currentUser.uid,
        ),
      ),
    );
  }
}
