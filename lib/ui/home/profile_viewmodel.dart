import 'package:flutter/material.dart';
import '../../data/service/profile_service.dart';
import '../../domain/model/user_profile.dart';

class ProfileViewModel extends ChangeNotifier {
  final _service = ProfileService();

  UserProfile? profile;
  bool isLoading = false;
  bool isSaving = false;

  Future<void> loadProfile(String uid) async {
    isLoading = true;
    notifyListeners();
    profile = await _service.getProfile(uid);
    isLoading = false;
    notifyListeners();
  }

  Future<bool> saveProfile(String uid, UserProfile p) async {
    isSaving = true;
    notifyListeners();
    try {
      await _service.saveProfile(uid, p);
      profile = p;
      isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
