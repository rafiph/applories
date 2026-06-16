import '../../domain/model/workout_plan.dart';

/// A built-in, offline library of exercises grouped by training focus.
class ExerciseLibrary {
  /// Catalog keyed by focus area. Sets/reps in the templates are placeholders;
  static const Map<String, List<Exercise>> catalog = {
    'Full Body': [
      Exercise(id: 'fb_burpees', name: 'Burpees', exerciseGroup: 'Full Body', sets: 3, reps: 12),
      Exercise(id: 'fb_jumping_jacks', name: 'Jumping Jacks', exerciseGroup: 'Full Body', sets: 3, reps: 30),
      Exercise(id: 'fb_mountain_climbers', name: 'Mountain Climbers', exerciseGroup: 'Full Body', sets: 3, reps: 20),
      Exercise(id: 'fb_squat_thrust', name: 'Squat Thrusts', exerciseGroup: 'Full Body', sets: 3, reps: 15),
    ],
    'Upper Body': [
      Exercise(id: 'ub_pushups', name: 'Push-ups', exerciseGroup: 'Upper Body', sets: 3, reps: 12),
      Exercise(id: 'ub_pike_pushups', name: 'Pike Push-ups', exerciseGroup: 'Upper Body', sets: 3, reps: 10),
      Exercise(id: 'ub_dips', name: 'Chair Dips', exerciseGroup: 'Upper Body', sets: 3, reps: 12),
      Exercise(id: 'ub_superman', name: 'Superman Hold', exerciseGroup: 'Upper Body', sets: 3, reps: 15),
      Exercise(id: 'ub_plank_taps', name: 'Plank Shoulder Taps', exerciseGroup: 'Upper Body', sets: 3, reps: 20),
    ],
    'Lower Body': [
      Exercise(id: 'lb_squats', name: 'Bodyweight Squats', exerciseGroup: 'Lower Body', sets: 3, reps: 15),
      Exercise(id: 'lb_lunges', name: 'Walking Lunges', exerciseGroup: 'Lower Body', sets: 3, reps: 12),
      Exercise(id: 'lb_glute_bridge', name: 'Glute Bridges', exerciseGroup: 'Lower Body', sets: 3, reps: 15),
      Exercise(id: 'lb_calf_raises', name: 'Calf Raises', exerciseGroup: 'Lower Body', sets: 3, reps: 20),
      Exercise(id: 'lb_wall_sit', name: 'Wall Sit', exerciseGroup: 'Lower Body', sets: 3, reps: 45),
    ],
    'Core': [
      Exercise(id: 'co_plank', name: 'Plank', exerciseGroup: 'Core', sets: 3, reps: 45),
      Exercise(id: 'co_crunches', name: 'Crunches', exerciseGroup: 'Core', sets: 3, reps: 20),
      Exercise(id: 'co_leg_raises', name: 'Leg Raises', exerciseGroup: 'Core', sets: 3, reps: 15),
      Exercise(id: 'co_russian_twist', name: 'Russian Twists', exerciseGroup: 'Core', sets: 3, reps: 30),
      Exercise(id: 'co_bicycle', name: 'Bicycle Crunches', exerciseGroup: 'Core', sets: 3, reps: 24),
    ],
    'Cardio': [
      Exercise(id: 'ca_high_knees', name: 'High Knees', exerciseGroup: 'Cardio', sets: 4, reps: 40),
      Exercise(id: 'ca_jump_rope', name: 'Jump Rope', exerciseGroup: 'Cardio', sets: 4, reps: 60),
      Exercise(id: 'ca_skaters', name: 'Skater Jumps', exerciseGroup: 'Cardio', sets: 3, reps: 20),
      Exercise(id: 'ca_butt_kicks', name: 'Butt Kicks', exerciseGroup: 'Cardio', sets: 3, reps: 40),
      Exercise(id: 'ca_jog', name: 'Jog in Place', exerciseGroup: 'Cardio', sets: 3, reps: 90),
    ],
  };

  /// All focuses available to choose from when adding a custom exercise.
  static List<String> get focuses => catalog.keys.toList();

  /// Returns a fresh copy of the pool for a focus (templates only).
  static List<Exercise> pool(String focus) =>
      List<Exercise>.from(catalog[focus] ?? const []);
}
