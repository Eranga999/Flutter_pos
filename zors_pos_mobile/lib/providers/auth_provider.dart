import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await ApiService.getToken();
    if (token != null) {
      // Load user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userData');
      if (userData != null) {
        try {
          _user = User.fromJson(jsonDecode(userData));
          _isAuthenticated = true;
        } catch (e) {
          _isAuthenticated = false;
          _user = null;
        }
      } else {
        _isAuthenticated = true; // Token exists but no user data
      }
    } else {
      _isAuthenticated = false;
      _user = null;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.login(username, password);
      if (result['success']) {
        // Store user data from the response
        if (result['data'] != null && result['data']['user'] != null) {
          _user = User.fromJson(result['data']['user']);
          // Save user data to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(result['data']['user']));
        }
        _isAuthenticated = true;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String name,
    String username,
    String email,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.register(name, username, email, password);
      if (result['success']) {
        _isAuthenticated = true;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    // Clear user data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
