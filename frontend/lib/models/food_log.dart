class FoodLog {
  final int id;
  final List<String> items;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double confidence;
  final DateTime loggedAt;
  final List<int> imageIds;

  const FoodLog({
    required this.id,
    required this.items,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.confidence,
    required this.loggedAt,
    required this.imageIds,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as int,
      items: List<String>.from((json['items'] as List?) ?? []),
      calories: (json['estimated_calories'] as num?)?.toInt() ?? 0,
      protein: (json['estimated_protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['estimated_fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['estimated_carbs'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      imageIds: List<int>.from((json['image_ids'] as List?) ?? []),
    );
  }
}
