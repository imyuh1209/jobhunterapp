import '../services/api_service.dart';

class AccountApi {
  final ApiService _api;
  AccountApi({ApiService? api}) : _api = api ?? ApiService();

  Future<Map<String, dynamic>> getMe() {
    return _api.getUserMe();
  }

  Future<bool> updateMe(Map<String, dynamic> payload) {
    return _api.updateUser(
      name: payload['name'],
      gender: payload['gender'],
      address: payload['address'],
      age: payload['age'],
      company: payload['company'],
    );
  }
}