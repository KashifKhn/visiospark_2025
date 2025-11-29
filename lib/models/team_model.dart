class TeamModel {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final int maxMembers;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional nested data
  final int? memberCount;
  final List<TeamMemberModel>? members;
  final String? eventTitle;

  TeamModel({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    this.maxMembers = 5,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount,
    this.members,
    this.eventTitle,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      maxMembers: json['max_members'] as int? ?? 5,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      memberCount: json['member_count'] as int?,
      members: json['team_members'] != null
          ? (json['team_members'] as List)
              .map((m) => TeamMemberModel.fromJson(m))
              .toList()
          : null,
      eventTitle: json['events'] != null
          ? (json['events'] as Map<String, dynamic>)['title'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'description': description,
      'max_members': maxMembers,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isFull => memberCount != null && memberCount! >= maxMembers;

  @override
  String toString() => 'Team($id, $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class TeamMemberModel {
  final String id;
  final String teamId;
  final String userId;
  final String role; // 'leader' or 'member'
  final DateTime joinedAt;

  // Optional nested data
  final String? userName;
  final String? userAvatar;
  final String? userEmail;

  TeamMemberModel({
    required this.id,
    required this.teamId,
    required this.userId,
    this.role = 'member',
    required this.joinedAt,
    this.userName,
    this.userAvatar,
    this.userEmail,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    
    return TeamMemberModel(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      userName: profile?['full_name'] as String?,
      userAvatar: profile?['avatar_url'] as String?,
      userEmail: profile?['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  bool get isLeader => role == 'leader';

  @override
  String toString() => 'TeamMember($id, $userName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamMemberModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class TeamMessageModel {
  final String id;
  final String teamId;
  final String userId;
  final String message;
  final DateTime createdAt;

  // Optional nested data
  final String? userName;
  final String? userAvatar;

  TeamMessageModel({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.userName,
    this.userAvatar,
  });

  factory TeamMessageModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    
    return TeamMessageModel(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: profile?['full_name'] as String?,
      userAvatar: profile?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'user_id': userId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'TeamMessage($id, $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamMessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
