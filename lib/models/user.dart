import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final bool isMe;

  @HiveField(3)
  final String? avatarColor;

  User({
    required this.id,
    required this.name,
    this.isMe = false,
    this.avatarColor,
  });

  User copyWith({
    String? id,
    String? name,
    bool? isMe,
    String? avatarColor,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      isMe: isMe ?? this.isMe,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }
}