import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_base.dart';
import 'models/achievement_model.dart';
import 'models/payment_model.dart';
import 'models/profile_detail_model.dart';
import 'models/subscription_model.dart';

class MyRepository {
  final Dio _dio;

  MyRepository(this._dio, {String? Function()? currentOwner})
      : _currentOwner = currentOwner {
    _guard = InterceptorsWrapper(onRequest: (options, handler) {
      if (options.extra.containsKey(_ownerKey) &&
          options.extra[_ownerKey] != _currentOwner?.call()) {
        handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: const ApiException(message: '계정이 변경되어 설정을 다시 확인해주세요.')));
        return;
      }
      handler.next(options);
    });
    _dio.interceptors.add(_guard);
  }

  final String? Function()? _currentOwner;
  late final Interceptor _guard;
  static const _ownerKey = '_profileExpectedOwner';

  void dispose() => _dio.interceptors.remove(_guard);

  Future<ProfileDetailModel> fetchProfileDetail() async {
    final response = await _dio.get<Map<String, dynamic>>('/user/profile');
    return ProfileDetailModel.fromJson(response.data!);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final owner = _currentOwner?.call();
    if (_currentOwner != null && owner == null) {
      throw const ApiException(message: '로그인한 계정의 설정을 다시 확인해주세요.');
    }
    await _dio.patch<Map<String, dynamic>>('/user/profile',
        data: data,
        options: _currentOwner == null
            ? null
            : Options(extra: {
                _ownerKey: owner,
                RequestMetadata.skipNetworkRetry: true,
                RequestMetadata.skipAuthRefresh: true,
              }));
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

  Future<List<AchievementItem>> fetchAchievements() async {
    final response = await _dio.get<Map<String, dynamic>>('/achievements');
    final list = response.data!['achievements'] as List<dynamic>? ?? [];
    return list
        .map((e) => AchievementItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteAccount() async {
    await _dio.delete<Map<String, dynamic>>('/user/account');
  }

  Future<({List<PaymentModel> payments, int totalPages})> fetchPayments(
      int page) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments',
      queryParameters: {'page': page},
    );
    final data = response.data!;
    final rawPayments = (data['payments'] as List<dynamic>?) ?? [];
    return (
      payments: rawPayments
          .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }
}
