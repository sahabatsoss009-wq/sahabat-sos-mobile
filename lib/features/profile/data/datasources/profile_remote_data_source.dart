import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/app_error_handler.dart';

abstract class ProfileRemoteDataSource {
  Future<Map<String, dynamic>> getProfile();
  Future<Map<String, dynamic>> getMe();
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateProfileWithFoto(
    Map<String, dynamic> data,
    XFile imageFile,
  );
  Future<Map<String, dynamic>> uploadFoto(XFile imageFile);
  Future<Map<String, dynamic>> deleteFoto();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio;
  final SharedPreferences prefs;

  ProfileRemoteDataSourceImpl({
    required this.dio,
    required this.prefs,
  });

  Map<String, dynamic> _getHeaders() {
    final token = prefs.getString('auth_token');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  MediaType _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is String) {
      return json.decode(data);
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dio.get(
        ApiConstants.profile,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      } else {
        throw Exception(
          response.data is Map && response.data['message'] != null
              ? response.data['message']
              : 'Gagal memuat data profil.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        AppErrorHandler.getFriendlyMessage(
          e,
          defaultMessage: 'Gagal memuat profil pengguna.',
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await dio.get(
        ApiConstants.me,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      } else {
        throw Exception(
          response.data is Map && response.data['message'] != null
              ? response.data['message']
              : 'Gagal memuat data pengguna.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        AppErrorHandler.getFriendlyMessage(
          e,
          defaultMessage: 'Gagal memuat profil akun.',
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await dio.put(
        ApiConstants.profile,
        data: data,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      } else {
        throw Exception(
          response.data is Map && response.data['message'] != null
              ? response.data['message']
              : 'Gagal memperbarui profil.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        AppErrorHandler.getFriendlyMessage(
          e,
          defaultMessage: 'Gagal memperbarui profil pengguna.',
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfileWithFoto(
    Map<String, dynamic> data,
    XFile imageFile,
  ) async {
    try {
      final map = <String, dynamic>{};
      data.forEach((key, value) {
        map[key] = value.toString();
      });

      final bytes = await imageFile.readAsBytes();
      final mimeType = _getMimeType(imageFile.name);

      map['foto_profile'] = MultipartFile.fromBytes(
        bytes,
        filename: imageFile.name,
        contentType: mimeType,
      );

      final formData = FormData.fromMap(map);

      // Gunakan POST endpoint /pengguna/profile yang mendukung multipart form-data
      final response = await dio.post(
        ApiConstants.profile,
        data: formData,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      } else {
        throw Exception(
          response.data is Map && response.data['message'] != null
              ? response.data['message']
              : 'Gagal memperbarui profil dan foto.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        AppErrorHandler.getFriendlyMessage(
          e,
          defaultMessage: 'Gagal memperbarui profil dan foto pengguna.',
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> uploadFoto(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final mimeType = _getMimeType(imageFile.name);

      final formData = FormData.fromMap({
        'foto_profile': MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
          contentType: mimeType,
        ),
      });

      final response = await dio.post(
        ApiConstants.profileFoto,
        data: formData,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      } else {
        throw Exception(
          response.data is Map && response.data['message'] != null
              ? response.data['message']
              : 'Gagal mengunggah foto profil.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        AppErrorHandler.getFriendlyMessage(
          e,
          defaultMessage: 'Gagal mengunggah foto profil.',
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> deleteFoto() async {
    try {
      final response = await dio.delete(
        ApiConstants.profileFoto,
        options: Options(headers: _getHeaders()),
      );

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      } else {
        throw Exception(
          response.data is Map && response.data['message'] != null
              ? response.data['message']
              : 'Gagal menghapus foto profil.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        AppErrorHandler.getFriendlyMessage(
          e,
          defaultMessage: 'Gagal menghapus foto profil.',
        ),
      );
    }
  }
}
