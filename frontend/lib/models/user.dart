class User {
  final int id;
  final String name;
  final int age;
  final double heightCm;
  final double currentWeight;
  final double goalWeight;
  final int xp;
  final int level;
  final String title;

  User({
    required this.id,
    required this.name,
    required this.age,
    required this.heightCm,
    required this.currentWeight,
    required this.goalWeight,
    required this.xp,
    required this.level,
    required this.title,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      age: json['age'] as int,
      heightCm: (json['height_cm'] as num).toDouble(),
      currentWeight: (json['current_weight'] as num).toDouble(),
      goalWeight: (json['goal_weight'] as num).toDouble(),
      xp: json['xp'] as int,
      level: json['level'] as int,
      title: json['title'] as String,
    );
  }
}
