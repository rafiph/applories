import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/service/food_service.dart';
import '../../data/service/vision_service.dart';
import '../../domain/model/food_log.dart';

class FoodLoggingViewModel extends ChangeNotifier {
  final FoodService _foodService = FoodService();
  final VisionService _visionService = VisionService();
  final ImagePicker _imagePicker = ImagePicker();

  List<FoodLog> foodLogs = [];
  bool isLoading = false;
  String? errorMessage;
  int totalCaloriesToday = 0;

  Future<Uint8List?> captureFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image == null) return null;
      return await image.readAsBytes();
    } catch (e) {
      errorMessage = 'Failed to capture image: $e';
      notifyListeners();
      return null;
    }
  }

  Future<Uint8List?> pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image == null) return null;
      return await image.readAsBytes();
    } catch (e) {
      errorMessage = 'Failed to pick image: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> analyzeFoodImageAndSave(Uint8List imageBytes, String userId) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final analysisResult = await _visionService.analyzeFoodImage(imageBytes);

      final foodLog = FoodLog(
        id: '',
        foodName: analysisResult['foodName'] as String,
        calories: analysisResult['calories'] as int,
        timestamp: DateTime.now(),
      );

      await _foodService.saveFoodLog(userId, foodLog);
      await loadFoodLogs(userId);

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Error analyzing food: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Returns raw AI result {foodName, calories} without saving.
  /// Caller decides what to do with the result.
  Future<Map<String, dynamic>?> reanalyzeImage(Uint8List imageBytes) async {
    try {
      return await _visionService.analyzeFoodImage(imageBytes);
    } catch (e) {
      errorMessage = 'Failed to analyze image: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateFoodLog(
    String userId,
    String foodLogId, {
    String? foodName,
    int? calories,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (foodName != null) updates['foodName'] = foodName;
      if (calories != null) updates['calories'] = calories;
      if (updates.isEmpty) return true;

      await _foodService.updateFoodLog(userId, foodLogId, updates);
      await loadFoodLogs(userId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to update food log: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadFoodLogs(String userId) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      foodLogs = await _foodService.getFoodLogsForDate(userId, DateTime.now());
      totalCaloriesToday =
          await _foodService.getTotalCaloriesForDate(userId, DateTime.now());

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load food logs: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFoodLog(String userId, String foodLogId) async {
    try {
      await _foodService.deleteFoodLog(userId, foodLogId);
      await loadFoodLogs(userId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete food log: $e';
      notifyListeners();
      return false;
    }
  }
}
