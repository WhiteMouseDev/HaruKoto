import 'package:dio/dio.dart';
import 'models/dashboard_model.dart';
import 'models/mission_model.dart';
import 'models/user_profile_model.dart';

class HomeRepository {
  final Dio _dio;

  HomeRepository(this._dio);

  Future<DashboardModel> fetchDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>('/stats/dashboard');
    return DashboardModel.fromJson(response.data!);
  }

  Future<UserProfileModel> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/user/profile');
    return UserProfileModel.fromJson(response.data!);
  }

  Future<int> updateDailyGoal(int goal) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/study/daily-goal',
      data: {'dailyGoal': goal},
    );
    return response.data!['dailyGoal'] as int;
  }

  Future<void> updateJlptLevel(String level) async {
    await _dio.patch<Map<String, dynamic>>(
      '/user/profile',
      data: {'jlptLevel': level},
    );
  }

  Future<List<MissionModel>> fetchTodayMissions() async {
    final response = await _dio.get<Map<String, dynamic>>('/missions/today');
    final list = response.data!['missions'] as List<dynamic>? ?? [];
    return list
        .map((e) => MissionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
