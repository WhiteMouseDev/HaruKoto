import 'package:dio/dio.dart';
import 'models/profile_detail_model.dart';
import 'models/subscription_model.dart';

class MyRepository {
  final Dio _dio;

  MyRepository(this._dio);

  Future<ProfileDetailModel> fetchProfileDetail() async {
    final response = await _dio.get<Map<String, dynamic>>('/user/profile');
    return ProfileDetailModel.fromJson(response.data!);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _dio.patch<Map<String, dynamic>>('/user/profile', data: data);
  }

  Future<SubscriptionStatus> fetchSubscriptionStatus() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/subscription/status');
    return SubscriptionStatus.fromJson(response.data!);
  }

  Future<void> cancelSubscription({String? reason}) async {
    await _dio.post<Map<String, dynamic>>(
      '/subscription/cancel',
      data: {'reason': reason},
    );
  }

  Future<void> resumeSubscription() async {
    await _dio.post<Map<String, dynamic>>('/subscription/resume');
  }

  Future<void> deleteAccount() async {
    await _dio.delete<Map<String, dynamic>>('/user/account');
  }

  Future<Map<String, dynamic>> fetchPayments(int page) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments',
      queryParameters: {'page': page},
    );
    return response.data!;
  }
}
