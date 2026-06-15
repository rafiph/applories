import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/health_metric.dart';

class HealthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _metricsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('healthMetrics');

  String _dateId(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> logWeight(String userId, DateTime date, double weight) async {
    try {
      final dateId = _dateId(date);
      await _metricsCollection(userId).doc(dateId).set({
        'date': DateTime(date.year, date.month, date.day),
        'weight': weight,
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error logging weight', error: e);
      rethrow;
    }
  }

  Future<void> addWater(String userId, DateTime date, int ml) async {
    try {
      final dateId = _dateId(date);
      await _metricsCollection(userId).doc(dateId).set({
        'date': DateTime(date.year, date.month, date.day),
        'waterIntakeMl': FieldValue.increment(ml),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error adding water intake', error: e);
      rethrow;
    }
  }

  Future<void> updateMetric(
    String userId,
    String metricId, {
    double? weight,
    int? waterIntakeMl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (weight != null) updates['weight'] = weight;
      if (waterIntakeMl != null) updates['waterIntakeMl'] = waterIntakeMl;
      if (updates.isEmpty) return;
      await _metricsCollection(userId).doc(metricId).update(updates);
    } catch (e) {
      developer.log('Error updating health metric', error: e);
      rethrow;
    }
  }

  Future<void> deleteMetric(String userId, String metricId) async {
    try {
      await _metricsCollection(userId).doc(metricId).delete();
    } catch (e) {
      developer.log('Error deleting health metric', error: e);
      rethrow;
    }
  }

  Future<List<HealthMetric>> getMetricsHistory(String userId) async {
    try {
      final snapshot = await _metricsCollection(userId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => HealthMetric.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error fetching health metrics history', error: e);
      rethrow;
    }
  }

  Future<HealthMetric?> getMetricForDate(String userId, DateTime date) async {
    try {
      final doc = await _metricsCollection(userId).doc(_dateId(date)).get();
      if (!doc.exists || doc.data() == null) return null;
      return HealthMetric.fromMap(doc.data()!, doc.id);
    } catch (e) {
      developer.log('Error fetching health metric for date', error: e);
      rethrow;
    }
  }
}
