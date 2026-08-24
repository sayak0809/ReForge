class UserQuest {
  final int id;
  final String title;
  final String description;
  final String questType;
  final double targetValue;
  final int xpReward;
  final String rarity;
  final bool completed;
  final bool autoCompleted;

  UserQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.questType,
    required this.targetValue,
    required this.xpReward,
    required this.rarity,
    required this.completed,
    required this.autoCompleted,
  });

  factory UserQuest.fromJson(Map<String, dynamic> json) {
    return UserQuest(
      id: json['user_quest_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      questType: json['quest_type'] as String,
      targetValue: (json['target_value'] as num).toDouble(),
      xpReward: json['xp_reward'] as int,
      rarity: json['rarity'] as String,
      completed: json['completed'] as bool,
      autoCompleted: json['auto_completed'] as bool? ?? false,
    );
  }
}
