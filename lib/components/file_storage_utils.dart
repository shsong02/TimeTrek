import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

class FileStorageUtils {
  static const String _basePath = 'users';
  
  static Future<Map<String, dynamic>> uploadImage({
    required String uid,
    required String goalName,
    required String actionName,
    required XFile image,
  }) async {
    return _uploadContent(
      uid: uid,
      goalName: goalName,
      actionName: actionName,
      type: 'images',
      fileName: image.name,
      getData: () async {
        final imageBytes = await image.readAsBytes();
        return _resizeImage(imageBytes);
      },
      contentType: 'image/jpeg',
    );
  }

  static Future<Map<String, dynamic>> uploadFile({
    required String uid,
    required String goalName,
    required String actionName,
    required PlatformFile file,
  }) async {
    if (file.bytes == null) throw Exception('파일 데이터가 없습니다.');
    
    return _uploadContent(
      uid: uid,
      goalName: goalName,
      actionName: actionName,
      type: 'files',
      fileName: file.name,
      getData: () async => file.bytes!,
      contentType: null,
    );
  }

  static Future<Map<String, dynamic>> _uploadContent({
    required String uid,
    required String goalName,
    required String actionName,
    required String type,
    required String fileName,
    required Future<Uint8List> Function() getData,
    String? contentType,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeGoalName = _getSafeName(goalName, 20);
      final safeActionName = _getSafeName(actionName, 20);
      
      final extension = fileName.split('.').last;
      final safeFileName = '${timestamp}.$extension';
      final gsPath = '$_basePath/$uid/$type/$safeGoalName/$safeActionName/$safeFileName';

      final data = await getData();
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'originalGoalName': goalName,
          'originalActionName': actionName,
          'type': type,
        },
      );

      final storageRef = FirebaseStorage.instance.ref().child(gsPath);
      await storageRef.putData(data, metadata);
      final url = await storageRef.getDownloadURL();

      return {
        'url': url,
        'gsPath': 'gs://${FirebaseStorage.instance.bucket}/$gsPath',
      };
    } catch (e) {
      print('$type 업로드 오류: $e');
      throw Exception('$type 업로드 실패: $e');
    }
  }

  static Future<void> deleteStorageFiles({
    required String uid,
    required String goalName,
    String? actionName,
  }) async {
    try {
      final safeGoalName = _getSafeName(goalName, 50);
      final types = ['images', 'files'];
      
      for (final type in types) {
        String basePath = '$_basePath/$uid/$type/$safeGoalName';
        
        if (actionName != null) {
          final safeActionName = _getSafeName(actionName, 50);
          basePath = '$basePath/$safeActionName';
        }

        try {
          print('삭제 시도 중: $basePath');
          final storageRef = FirebaseStorage.instance.ref().child(basePath);
          await _recursiveDelete(storageRef);
          print('삭제 완료: $basePath');
        } catch (e) {
          print('개별 타입 삭제 중 오류 발생: $e');
          continue;
        }
      }
    } catch (e) {
      print('파일 삭제 중 오류: $e');
      throw Exception('파일 삭제 실패: $e');
    }
  }

  static Future<void> _recursiveDelete(Reference ref) async {
    final result = await ref.listAll();
    
    for (var prefix in result.prefixes) {
      await _recursiveDelete(prefix);
    }
    
    for (var item in result.items) {
      print('Google Storage 파일 삭제: ${item.fullPath}');
      await item.delete();
    }
  }

  // 유틸리티 메서드들
  static String _getSafeName(String name, int maxLength) {
    return name.substring(0, name.length > maxLength ? maxLength : name.length)
        .replaceAll(RegExp(r'[^a-zA-Z0-9가-힣]'), '_');
  }

  static Future<Uint8List> _resizeImage(Uint8List imageData) async {
    final image = img.decodeImage(imageData);
    if (image == null) return imageData;

    int quality = 100;
    Uint8List resizedImageData;
    do {
      resizedImageData = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      quality -= 10;
    } while (resizedImageData.lengthInBytes > 1024 * 1024 && quality > 0);

    return resizedImageData;
  }

  static Future<String?> getActualImageUrl(String? url) async {
    if (url == null || url.isEmpty) return null;

    if (url.startsWith('gs://')) {
      try {
        final storage = FirebaseStorage.instance;
        final gsReference = storage.refFromURL(url);
        
        // 직접 다운로드 URL만 반환
        final downloadUrl = await gsReference.getDownloadURL();
        // print('변환된 URL: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        print('Firebase Storage URL 변환 오류: $e');
        return null;
      }
    }

    // 이미 https:// URL인 경우
    if (url.startsWith('https://')) {
      return url;
    }

    // 기타 URL 처리
    return url;
  }

  static Future<bool> canOpenUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.head(uri);
      return response.statusCode == 200;
    } catch (e) {
      print('URL 확인 중 오류: $e');
      return false;
    }
  }
} 