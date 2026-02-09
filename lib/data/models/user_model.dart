class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String username;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'username': username,
    };
  }
}
