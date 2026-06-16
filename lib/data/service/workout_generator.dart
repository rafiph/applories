import 'dart:math';
import '../../domain/model/user_profile.dart';
import '../../domain/model/workout_plan.dart';
import 'exercise_library.dart';

class WorkoutGoal {
  static const weightLoss = 'Weight Loss';
}

class WorkoutGenerator {
  static const Map<String, List<String>> weeklyTemplate = {
    WorkoutGoal.weightLoss: [
      'Cardio',
      'Full Body',
      'Cardio',
      'Lower Body',
      'Core',
      'Full Body',
      'Rest',
      ],
  };

  static WorkoutPlan generatePlan({required UserProfile profile, required String goal,int weeks = 4,}) {
    final focusAreas = weeklyTemplate[WorkoutGoal.weightLoss];
    final rng = Random(profile.hashCode ^ goal.hashCode);
    
    final ageFactoring = profile.age > 50 ? 0.85 : (profile.age > 35 ? 0.95 : 1.0);
    final loseWeight = goal == WorkoutGoal.weightLoss;
    final repBoost = loseWeight ? 1.15 : 1.0;

    final workoutDays = <WorkoutDay>[];
    var dayCounter = 1;

    for (var week = 0; week < weeks; week++) {
      for (final focus in focusAreas!) {
        if (focus == 'Rest') {
          workoutDays.add(WorkoutDay(dayNumber: dayCounter++, focus: 'Rest', isRestDay: true));
          continue;
        }

        final pool = ExerciseLibrary.pool(focus);
        pool.shuffle(rng);
        final selectedExercises = pool.take(min(4, pool.length)).map((exercise) {
          final sets = loseWeight ? 3 : 4;
          final reps = (exercise.reps * repBoost * ageFactoring).round().clamp(8, 20);
          return exercise.copyWith(sets: sets, reps: reps);
        }).toList();

        workoutDays.add(WorkoutDay(dayNumber: dayCounter++, focus: focus, exercises: selectedExercises));
      }
    }
    return WorkoutPlan(goal: goal, durationWeeks: weeks, startDate: DateTime.now(), workoutDays: workoutDays);
  }
}