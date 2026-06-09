class FoodLog {
  final String id;
  final String foodName;
  final int calories;
  final DateTime timestamp;
  final String? imageUrl;

  FoodLog({
    required this.id,
    required this.foodName,
    required this.calories,
    required this.timestamp,
    this.imageUrl,
  });

  factory FoodLog.fromMap(Map<String, dynamic> data, String id) => FoodLog(
        id: id,
        foodName: data['foodName'] ?? '',
        calories: data['calories'] ?? 0,
        timestamp: data['timestamp'] is DateTime
            ? data['timestamp'] as DateTime
            : DateTime.fromMillisecondsSinceEpoch(
                (data['timestamp'] as dynamic)?.millisecondsSinceEpoch ?? 0),
        imageUrl: data['imageUrl'],
      );

  Map<String, dynamic> toMap() => {
        'foodName': foodName,
        'calories': calories,
        'timestamp': timestamp,
        'imageUrl': imageUrl,
      };
}
