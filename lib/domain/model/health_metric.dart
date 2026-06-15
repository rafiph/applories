class HealthMetric {
  final String id;
  final DateTime date;
  final double? weight; // kg, null if not logged for this day
  final int waterIntakeMl;

  HealthMetric({
    required this.id,
    required this.date,
    this.weight,
    this.waterIntakeMl = 0,
  });

  factory HealthMetric.fromMap(Map<String, dynamic> data, String id) =>
      HealthMetric(
        id: id,
        date: data['date'] is DateTime
            ? data['date'] as DateTime
            : DateTime.fromMillisecondsSinceEpoch(
                (data['date'] as dynamic)?.millisecondsSinceEpoch ?? 0),
        weight: (data['weight'] as num?)?.toDouble(),
        waterIntakeMl: (data['waterIntakeMl'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {
        'date': date,
        'weight': weight,
        'waterIntakeMl': waterIntakeMl,
      };

  HealthMetric copyWith({double? weight, int? waterIntakeMl}) => HealthMetric(
        id: id,
        date: date,
        weight: weight ?? this.weight,
        waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      );
}
