import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'db_service.dart';
import 'push_notification_service.dart';

class AuthService with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  AppUser? _currentUser;
  bool _isLoading = true;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthService() {
    _loadUserSession();
  }

  Future<void> _cacheUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_cache_${user.pnr}', jsonEncode(user.toMap()));
  }

  AppUser? _readCachedUser(SharedPreferences prefs, String pnr) {
    final raw = prefs.getString('user_cache_$pnr');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AppUser.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshUserFromDb(String pnr) async {
    try {
      final user = await _dbService.getUserByPnr(pnr);
      if (user == null) return;
      _currentUser = user;
      await _cacheUser(user);
      PushNotificationService.updateFcmToken(pnr);
      notifyListeners();
    } catch (e) {
      debugPrint("Error refreshing user: $e");
    }
  }

  Future<void> _loadUserSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final pnr = prefs.getString('user_pnr');

      if (pnr != null) {
        if (pnr == 'admin') {
          _currentUser = AppUser(
            pnr: 'admin',
            name: 'Administrator',
            role: 'admin',
            isApproved: true,
          );
        } else {
          // Show cached user immediately (fast startup), then refresh from DB.
          final cached = _readCachedUser(prefs, pnr);
          if (cached != null) {
            _currentUser = cached;
            _isLoading = false;
            notifyListeners();
            PushNotificationService.updateFcmToken(pnr);
            unawaited(_refreshUserFromDb(pnr));
            return;
          }

          _currentUser = await _dbService.getUserByPnr(pnr);
          if (_currentUser != null) {
            await _cacheUser(_currentUser!);
            PushNotificationService.updateFcmToken(pnr);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading session: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String pnr, String password) async {
    try {
      // 1. Check if admin
      if (pnr == 'admin' && password == 'admin@wit') {
        _currentUser = AppUser(
          pnr: 'admin',
          name: 'Administrator',
          role: 'admin',
          isApproved: true,
        );
        await _saveSession('admin');
        notifyListeners();
        return null; // Success
      }

      // 2. Otherwise check database for student/faculty
      final user = await _dbService.authenticateUser(pnr, password);

      if (user != null) {
        if (!user.isApproved) {
          return "Account pending approval from Administrator.";
        }
        _currentUser = user;
        await _saveSession(pnr);
        await _cacheUser(user);
        PushNotificationService.updateFcmToken(pnr);
        notifyListeners();
        return null; // Success
      } else {
        return "Invalid PNR or password.";
      }
    } catch (e) {
      return "Login failed: $e";
    }
  }

  Future<String?> registerStudent(
    String pnr,
    String name,
    String password,
  ) async {
    try {
      final newUser = AppUser(
        pnr: pnr.trim(),
        name: name.trim(),
        role: 'student',
        isApproved: false,
      );

      await _dbService.requestAccount(newUser, password);
      return null; // Success
    } catch (e) {
      return "Registration failed: $e";
    }
  }

  Future<String?> registerFaculty(
    String pnr,
    String name,
    String password,
  ) async {
    try {
      final newUser = AppUser(
        pnr: pnr.trim(),
        name: name.trim(),
        role: 'faculty',
        isApproved: false,
      );

      await _dbService.requestAccount(newUser, password);
      return null;
    } catch (e) {
      return "Registration failed: $e";
    }
  }

  Future<void> refreshCurrentUser() async {
    final currentPnr = _currentUser?.pnr;
    if (currentPnr == null || currentPnr == 'admin') {
      return;
    }

    final refreshedUser = await _dbService.getUserByPnr(currentPnr);
    if (refreshedUser != null) {
      _currentUser = refreshedUser;
      await _cacheUser(refreshedUser);
      notifyListeners();
    }
  }

  Future<void> _saveSession(String pnr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pnr', pnr);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pnr');
    _currentUser = null;
    notifyListeners();
  }
}
