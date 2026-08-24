class WeightLog {
  final int id;
  final double weight;
  final DateTime loggedAt;

  WeightLog({required this.id, required this.weight, required this.loggedAt});

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'] as int,
      weight: (json['weight'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] as String),
    );
  }
}
