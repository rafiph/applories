import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/service/food_service.dart';
import '../../data/service/storage_service.dart';
import '../../data/service/vision_service.dart';
import '../../domain/model/food_log.dart';

class FoodLoggingViewModel extends ChangeNotifier {
  final FoodService _foodService = FoodService();
  final VisionService _visionService = VisionService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  List<FoodLog> foodLogs = [];
  bool isLoading = false;
  String? errorMessage;
  int totalCaloriesForDate = 0;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  bool get isViewingToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── Date navigation ────────────────────────────────────────────────────────

  Future<void> changeDate(String userId, DateTime date) async {
    _selectedDate = date;
    await loadFoodLogs(userId);
  }

  Future<void> goToPreviousDay(String userId) =>
      changeDate(userId, _selectedDate.subtract(const Duration(days: 1)));

  Future<void> goToNextDay(String userId) =>
      changeDate(userId, _selectedDate.add(const Duration(days: 1)));

  // ── Image picking ──────────────────────────────────────────────────────────

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

  // ── Core actions ───────────────────────────────────────────────────────────

  /// Runs Gemini analysis and iDrive e2 upload concurrently, then saves
  /// the resulting [FoodLog] (with imageUrl) to Firestore.
  Future<bool> analyzeFoodImageAndSave(
      Uint8List imageBytes, String userId) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Parallel: vision analysis + cloud upload — neither depends on the other.
      final results = await Future.wait([
        _visionService.analyzeFoodImage(imageBytes),
        _storageService.uploadFoodImage(userId, imageBytes),
      ]);

      final analysisResult = results[0] as Map<String, dynamic>;
      final imageUrl = results[1] as String;

      final foodLog = FoodLog(
        id: '',
        foodName: analysisResult['foodName'] as String,
        calories: analysisResult['calories'] as int,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
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

  /// Re-analyzes a new image for an existing log. Uploads the image and
  /// returns { foodName, calories, imageUrl } so the caller can decide
  /// what to update.
  Future<Map<String, dynamic>?> reanalyzeImage(
      String userId, Uint8List imageBytes) async {
    try {
      final results = await Future.wait([
        _visionService.analyzeFoodImage(imageBytes),
        _storageService.uploadFoodImage(userId, imageBytes),
      ]);

      return {
        ...(results[0] as Map<String, dynamic>),
        'imageUrl': results[1] as String,
      };
    } catch (e) {
      errorMessage = 'Failed to analyze image: $e';
      notifyListeners();
      return null;
    }
  }

  /// Updates an existing food log. Pass [imageUrl] to persist a new image URL.
  Future<bool> updateFoodLog(
    String userId,
    String foodLogId, {
    String? foodName,
    int? calories,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (foodName != null) updates['foodName'] = foodName;
      if (calories != null) updates['calories'] = calories;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
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

      foodLogs = await _foodService.getFoodLogsForDate(userId, _selectedDate);
      totalCaloriesForDate =
          await _foodService.getTotalCaloriesForDate(userId, _selectedDate);

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