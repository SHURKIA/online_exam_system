import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../data/services/api_service.dart';

class GradingController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<dynamic> submissions = <dynamic>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSubmissions();
  }

  Future<void> fetchSubmissions() async {
    try {
      isLoading.value = true;
      // Endpoint: GET /teacher/submissions
      final response = await _apiService.get('/teacher/submissions');

      if (response['success'] == true) {
        submissions.value = response['data'];
      }
    } catch (e) {
      print('Error: $e');
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to load submissions: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> gradeAnswer(int answerId, int score) async {
    try {
      final response = await _apiService.post('/teacher/grade/$answerId', {
        'score': score,
      });

      if (response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("DEBUG: Error grading answer: $e");
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to save grade: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchSubmissionDetails(int submissionId) async {
    try {
      debugPrint(
        "DEBUG: GradingController - fetchSubmissionDetails starting for ID: $submissionId",
      );
      final response = await _apiService.get(
        '/teacher/submissions/$submissionId',
      );

      debugPrint(
        "DEBUG: GradingController - response received: ${response != null}",
      );

      if (response != null && response['success'] == true) {
        debugPrint("DEBUG: GradingController - success!");
        return response['data'];
      }
      debugPrint("DEBUG: GradingController - failed or success: false");
      return null;
    } catch (e, stack) {
      debugPrint("DEBUG: GradingController - Error: $e");
      debugPrint("DEBUG: GradingController - Stack: $stack");
      // Removing dialog from here to avoid potential animation crashes during screen transition
      // We let the screen handle the error UI
      return null;
    } finally {
      debugPrint("DEBUG: GradingController - fetchSubmissionDetails finished");
    }
  }
}
