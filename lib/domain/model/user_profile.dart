class UserProfile {
  final String name;
  final int age;
  final String gender;
  final double weight; // kg
  final double height; // cm

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) => UserProfile(
        name: data['name'] ?? '',
        age: (data['age'] ?? 0).toInt(),
        gender: data['gender'] ?? 'Male',
        weight: (data['weight'] ?? 0.0).toDouble(),
        height: (data['height'] ?? 0.0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender,
        'weight': weight,
        'height': height,
      };
}
