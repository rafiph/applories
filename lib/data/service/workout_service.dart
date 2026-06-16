import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/workout_plan.dart';

class WorkoutService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _planDoc(String uid) =>
      _db.collection('users').doc(uid).collection('workoutPlans').doc('active');

  Future<WorkoutPlan?> getActivePlan(String uid) async {
    final doc = await _planDoc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return WorkoutPlan.fromMap(doc.data()!);
  }

  Stream<WorkoutPlan?> activePlanStream(String uid) =>
      _planDoc(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return WorkoutPlan.fromMap(snapshot.data()!);
      });

  Future<void> saveActivePlan(String uid, WorkoutPlan plan) =>
      _planDoc(uid).set(plan.toMap());
  
  Future<void> deleteActivePlan(String uid) => _planDoc(uid).delete();
}