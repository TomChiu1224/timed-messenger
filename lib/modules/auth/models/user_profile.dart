class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String photoURL;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoURL,
    this.createdAt,
  });

  // 轉成 Map（存入 Firestore 用）
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoURL,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  // 從 Map 還原（從 Firestore 讀取用）
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      photoURL: map['photo_url'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
    );
  }
}
