class GroupMember {
  final String uid;
  final String displayName;
  final String role; // 'admin' 或 'member'

  GroupMember({
    required this.uid,
    required this.displayName,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'role': role,
      };

  factory GroupMember.fromMap(Map<String, dynamic> map) => GroupMember(
        uid: map['uid'] ?? '',
        displayName: map['displayName'] ?? '',
        role: map['role'] ?? 'member',
      );
}

class GroupModel {
  final String groupId;
  final String name;
  final String creatorId;
  final List<GroupMember> members;
  final DateTime createdAt;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.creatorId,
    required this.members,
    required this.createdAt,
  });

  factory GroupModel.fromFirestore(String id, Map<String, dynamic> data) {
    final membersList = (data['members'] as List<dynamic>? ?? [])
        .map((m) => GroupMember.fromMap(m as Map<String, dynamic>))
        .toList();
    return GroupModel(
      groupId: id,
      name: data['name'] ?? '',
      creatorId: data['creatorId'] ?? '',
      members: membersList,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'creatorId': creatorId,
        'members': members.map((m) => m.toMap()).toList(),
        'createdAt': createdAt,
      };
}
