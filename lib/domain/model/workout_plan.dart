class Exercise {
  final String id;
  final String name;
  final String exerciseGroup;
  final int sets;
  final int reps;
  final bool isCustom;
  final bool completed;

  const Exercise({
    required this.id,
    required this.name,
    required this.exerciseGroup,
    required this.sets,
    required this.reps,
    this.isCustom = false,
    this.completed = false,
  });

  Exercise copyWith({
    String? id,
    String? name,
    String? exerciseGroup,
    int? sets,
    int? reps,
    bool? isCustom,
    bool? completed,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      exerciseGroup: exerciseGroup ?? this.exerciseGroup,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      isCustom: isCustom ?? this.isCustom,
      completed: completed ?? this.completed,
    );
  }

  factory Exercise.fromMap(Map<String, dynamic> data, String id) => Exercise(
        id: id,
        name: data['name'] ?? '',
        exerciseGroup: data['exerciseGroup'] ?? '',
        sets: data['sets'] ?? 0,
        reps: data['reps'] ?? 0,
        isCustom: data['isCustom'] ?? false,
        completed: data['completed'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'exerciseGroup': exerciseGroup,
        'sets': sets,
        'reps': reps,
        'isCustom': isCustom,
        'completed': completed,
      };
}

class WorkoutDay {
  final int dayNumber;
  final String focus;
  final bool isRestDay;
  final List<Exercise> exercises;

  const WorkoutDay({
    required this.dayNumber,
    required this.focus,
    this.isRestDay = false,
    this.exercises = const [],
  });

  bool get isCompleted => isRestDay || (exercises.isNotEmpty && exercises.every((exercise) => exercise.completed));

  int get completedExercisesCount => exercises.where((exercise) => exercise.completed).length;

  WorkoutDay copyWith({
    int? dayNumber,
    String? focus,
    bool? isRestDay,
    List<Exercise>? exercises,
  }) {
    return WorkoutDay(
      dayNumber: dayNumber ?? this.dayNumber,
      focus: focus ?? this.focus,
      isRestDay: isRestDay ?? this.isRestDay,
      exercises: exercises ?? this.exercises,
    );
  }

  factory WorkoutDay.fromMap(Map<String, dynamic> data) => WorkoutDay(
        dayNumber: data['dayNumber'] ?? 0,
        focus: data['focus'] ?? '',
        isRestDay: data['isRestDay'] ?? false,
        exercises: (data['exercises'] as List<dynamic>? ?? [])
            .map((exerciseData) => Exercise.fromMap(exerciseData as Map<String, dynamic>, exerciseData['id'] as String))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'dayNumber': dayNumber,
        'focus': focus,
        'isRestDay': isRestDay,
        'exercises': exercises.map((exercise) => exercise.toMap()).toList(),
      };
}

class WorkoutPlan {
  final String goal;
  final int durationWeeks;
  final DateTime startDate;
  final List<WorkoutDay> workoutDays;

  const WorkoutPlan({
    required this.goal,
    required this.durationWeeks,
    required this.startDate,
    this.workoutDays = const [],
  });

  int get totalExercises => workoutDays.fold(0, (total, day) => total + day.exercises.length);

  int get completedExercises => workoutDays.fold(0, (total, day) => total + day.completedExercisesCount);

  double get progress => totalExercises == 0 ? 0 : completedExercises / totalExercises;

  WorkoutPlan copyWith({
    String? goal,
    int? durationWeeks,
    DateTime? startDate,
    List<WorkoutDay>? workoutDays,
  }) {
    return WorkoutPlan(
      goal: goal ?? this.goal,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      startDate: startDate ?? this.startDate,
      workoutDays: workoutDays ?? this.workoutDays,
    );
  }

  factory WorkoutPlan.fromMap(Map<String, dynamic> data) => WorkoutPlan(
        goal: data['goal'] ?? '',
        durationWeeks: data['durationWeeks'] ?? 0,
        startDate: data['startDate'] is DateTime
            ? data['startDate'] as DateTime
            : DateTime.fromMillisecondsSinceEpoch(
                (data['startDate'] as dynamic)?.millisecondsSinceEpoch ?? 0),
        workoutDays: (data['workoutDays'] as List<dynamic>? ?? [])
            .map((dayData) => WorkoutDay.fromMap(dayData as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'goal': goal,
        'durationWeeks': durationWeeks,
        'startDate': startDate,
        'workoutDays': workoutDays.map((day) => day.toMap()).toList(),
      };
}