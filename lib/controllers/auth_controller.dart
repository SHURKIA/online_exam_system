import 'package:get/get.dart';
import '../data/services/api_service.dart';
import '../data/models/user_model.dart';
import '../screens/auth/login_screen.dart';
// import '../screens/student/student_dashboard.dart'; // Will create later
// import '../screens/teacher/teacher_dashboard.dart'; // Will create later

class AuthController extends GetxController {
  final ApiService _apiService = Get.put(ApiService());

  final Rx<User?> user = Rx<User?>(null);
  final RxBool isLoading = false.obs;

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        final data = response['data'];
        user.value = User.fromJson(data['user']);
        final String accessToken = data['tokens']['accessToken'];

        _apiService.setToken(accessToken);

        _navigateBasedOnRole();
      } else {
        Get.defaultDialog(
          title: 'Login Failed',
          middleText: response['message'] ?? 'Invalid email or password',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      print('Login error: $e');
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Login failed. Please check your connection or try again.',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _navigateBasedOnRole() {
    if (user.value?.role == 'student') {
      Get.offAllNamed('/student');
    } else if (user.value?.role == 'teacher') {
      Get.offAllNamed('/teacher');
    } else {
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Unknown role',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
  }

  void logout() {
    user.value = null;
    _apiService.setToken('');
    Get.offAll(() => const LoginScreen());
  }
}
