import 'package:flutter/material.dart';
import '../../data/service/workout_generator.dart';
import '../../data/service/workout_service.dart';
import '../../domain/model/user_profile.dart';
import '../../domain/model/workout_plan.dart';

class WorkoutViewModel extends ChangeNotifier {
  final WorkoutService _workoutService = WorkoutService();
  WorkoutPlan? activePlan;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  bool get hasActivePlan => activePlan != null;
  Future<void> loadActivePlan(String uid) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      activePlan = await _workoutService.getActivePlan(uid);
    } catch (e) {
      errorMessage = 'Failed to load workout plan: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generateAndSave({required String uid, required UserProfile profile, required String goal, int weeks = 4,}) 
  async {
    isSaving = true;
    notifyListeners();
    try {
      final newPlan = WorkoutGenerator.generatePlan(profile: profile, goal: goal, weeks: weeks);
      await _workoutService.saveActivePlan(uid, newPlan);
      activePlan = newPlan;
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to generate workout plan: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> setExerciseCompleted({required String uid, required int dayNumber, required String exerciseId, required bool completed}) 
  async {
    _mutateExercise(dayNumber, exerciseId, (exercise) => exercise.copyWith(completed: completed));
    await _persistChanges(uid);
  }

  Future<void> editExercise({required String uid, required int dayNumber, required String exerciseId, int? sets, int? reps}) 
  async {
    _mutateExercise(dayNumber, exerciseId, (exercise) => exercise.copyWith(sets: sets ?? exercise.sets, reps: reps ?? exercise.reps));
    await _persistChanges(uid);
  }

  Future<void> addCustomExercise({
    required String uid, required int dayNumber, required String name, required String exerciseGroup, required int sets, required int reps}
    ) async {
      if (activePlan == null) return;
      final newExercise = Exercise(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        exerciseGroup: exerciseGroup,
        sets: sets,
        reps: reps,
        isCustom: true,
      );
      final dayIndex = activePlan!.workoutDays.map((day){
        if (day.dayNumber != dayNumber) return day;
        return day.copyWith(
          isRestDay: false,
          exercises: [...day.exercises, newExercise],
        );
      }).toList();
      activePlan = activePlan!.copyWith(workoutDays: dayIndex);
      notifyListeners();
      await _persistChanges(uid);
    }

  Future<bool> regeneratePlan({required String uid, required UserProfile profile, String? goal, int? weeks}) =>
    generateAndSave(uid: uid, profile: profile, goal: goal ?? activePlan?.goal ?? WorkoutGoal.weightLoss, weeks: weeks ?? activePlan?.durationWeeks ?? 4);

  Future<void> deleteExercise({required String uid, required int dayNumber, required String exerciseId}) async {
    if (activePlan == null) return;
    final dayIndex = activePlan!.workoutDays.map((day){
      if (day.dayNumber != dayNumber) return day;
      return day.copyWith(
        exercises: day.exercises.where((exercise) => exercise.id != exerciseId).toList(),
      );
    }).toList();
    activePlan = activePlan!.copyWith(workoutDays: dayIndex);
    notifyListeners();
    await _persistChanges(uid);
  }

  Future<bool> deletePlan(String uid) async {
    isSaving = true;
    notifyListeners();
    try {
      await _workoutService.deleteActivePlan(uid);
      activePlan = null;
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete workout plan: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _mutateExercise(int dayNumber, String exerciseId, Exercise Function(Exercise) transform) 
  async {
    if (activePlan == null) return;
    final dayIndex = activePlan!.workoutDays.map((day){
      if (day.dayNumber != dayNumber) return day;
      return day.copyWith(
        exercises: day.exercises.map((exercise){
          if (exercise.id != exerciseId) return exercise;
          return transform(exercise);
        }).toList(),
      );
    }).toList();
    activePlan = activePlan!.copyWith(workoutDays: dayIndex);
    notifyListeners();
  }
    
  Future<void> _persistChanges(String uid) async {
    if (activePlan == null) return;
    try {
      await _workoutService.saveActivePlan(uid, activePlan!);
    } catch (e) {
      errorMessage = 'Failed to save workout plan: $e';
      notifyListeners();
    }
  }
}