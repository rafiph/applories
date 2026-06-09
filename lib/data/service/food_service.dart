import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/food_log.dart';

class FoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> saveFoodLog(String userId, FoodLog foodLog) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('foodLogs')
          .add(foodLog.toMap());
      return docRef.id;
    } catch (e) {
      developer.log('Error saving food log', error: e);
      rethrow;
    }
  }

  Future<List<FoodLog>> getUserFoodLogs(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('foodLogs')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FoodLog.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error fetching food logs', error: e);
      rethrow;
    }
  }

  Future<List<FoodLog>> getFoodLogsForDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('foodLogs')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FoodLog.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error fetching food logs for date', error: e);
      rethrow;
    }
  }

  Future<void> deleteFoodLog(String userId, String foodLogId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('foodLogs')
          .doc(foodLogId)
          .delete();
    } catch (e) {
      developer.log('Error deleting food log', error: e);
      rethrow;
    }
  }

  Future<int> getTotalCaloriesForDate(String userId, DateTime date) async {
    try {
      final logs = await getFoodLogsForDate(userId, date);
      return logs.fold<int>(0, (total, log) => total + log.calories);
    } catch (e) {
      developer.log('Error calculating total calories', error: e);
      rethrow;
    }
  }
}