import 'package:dio/dio.dart';
import '../../my/data/models/subscription_model.dart';

class SubscriptionRepository {
  final Dio _dio;

  SubscriptionRepository(this._dio);

  Future<SubscriptionStatus> fetchStatus() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/subscription/status');
    return SubscriptionStatus.fromJson(response.data!);
  }
}
