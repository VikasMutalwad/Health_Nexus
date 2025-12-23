// Location: lib/models/user_session.dart

class UserSession {
  final String username;
  final String role;
  final String userId;
  final String name;
  final int age;
  final String gender;
  final String dob;
  final double weight;
  final double height;

  UserSession({
    required this.username,
    required this.role,
    required this.userId,
    this.name = '',
    this.age = 0,
    this.gender = 'Male',
    this.dob = '',
    this.weight = 70.0,
    this.height = 175.0,
  });
}