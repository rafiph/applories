import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/user_profile.dart';

class ProfileService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<void> saveProfile(String uid, UserProfile profile) =>
      _userDoc(uid).set(profile.toMap(), SetOptions(merge: true));
}
