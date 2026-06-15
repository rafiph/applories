import 'package:flutter/material.dart';
import '../../data/service/health_service.dart';
import '../../data/service/food_service.dart';
import '../../domain/model/health_metric.dart';

class ProgressViewModel extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final FoodService _foodService = FoodService();

  static const int waterGoalMl = 2000;
  static const int cupSizeMl = 250;

  List<HealthMetric> metrics = [];
  int todayCalories = 0;
  bool isLoading = false;
  String? errorMessage;

  HealthMetric? get todayMetric {
    final now = DateTime.now();
    for (final metric in metrics) {
      if (metric.date.year == now.year &&
          metric.date.month == now.month &&
          metric.date.day == now.day) {
        return metric;
      }
    }
    return null;
  }

  int get todayWaterIntakeMl => todayMetric?.waterIntakeMl ?? 0;

  double get todayWaterIntakeCups => todayWaterIntakeMl / cupSizeMl;

  int get waterGoalCups => (waterGoalMl / cupSizeMl).round();

  List<HealthMetric> get weightHistory =>
      metrics.where((m) => m.weight != null).toList().reversed.toList();

  Future<void> loadMetrics(String userId) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      metrics = await _healthService.getMetricsHistory(userId);
      todayCalories = await _foodService.getTotalCaloriesForDate(userId, DateTime.now());

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load progress data: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logWeight(String userId, double weight) async {
    try {
      await _healthService.logWeight(userId, DateTime.now(), weight);
      await loadMetrics(userId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to log weight: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addWater(String userId, int ml) async {
    try {
      await _healthService.addWater(userId, DateTime.now(), ml);
      await loadMetrics(userId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to log water intake: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addWaterCups(String userId, int cups) =>
      addWater(userId, cups * cupSizeMl);

  Future<bool> updateMetric(
    String userId,
    String metricId, {
    double? weight,
    int? waterIntakeMl,
  }) async {
    try {
      await _healthService.updateMetric(
        userId,
        metricId,
        weight: weight,
        waterIntakeMl: waterIntakeMl,
      );
      await loadMetrics(userId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to update entry: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMetric(String userId, String metricId) async {
    try {
      await _healthService.deleteMetric(userId, metricId);
      await loadMetrics(userId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete entry: $e';
      notifyListeners();
      return false;
    }
  }
}
