class User {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final bool isPremium;
  List<String>? favoredPlaces;
  List<String>? addedPlaces;
  List<String>? friends;

  final String? photoUrl;

  User({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.isPremium = false,
    this.photoUrl,
    this.favoredPlaces,
    this.addedPlaces,
    this.friends,
  });

  factory User.fromMap(Map<String, dynamic> map, String uid) {
    return User(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isPremium: map['isPremium'] ?? false,
      photoUrl: map['photoUrl'],
      favoredPlaces: List<String>.from(map['favoredPlaces'] ?? []),
      addedPlaces: List<String>.from(map['addedPlaces'] ?? []),
      friends: List<String>.from(map['friends'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'isPremium': isPremium ?? false,
      'photoUrl': photoUrl,
      'favoredPlaces': favoredPlaces,
      'addedPlaces': addedPlaces,
      'friends': friends,
    };
  }
}
