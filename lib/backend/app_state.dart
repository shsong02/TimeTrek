import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // 이미지 관련 상수
  static const int actionMaxImageCount = 10;
  static const int actionLimitImageMBSize = 2;
  
  // 파일 관련 상수  
  static const int actionMaxFileCount = 3;
  static const int actionLimitFileMBSize = 10;

  // 기타 앱 전역 상태 변수들
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  set isDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  // 필요한 다른 상태 변수들 추가...
} 