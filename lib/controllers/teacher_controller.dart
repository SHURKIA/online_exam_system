import 'package:get/get.dart';
import '../data/models/exam_model.dart';
import '../data/services/api_service.dart';

class TeacherController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<Exam> exams = <Exam>[].obs;
  final RxBool isLoading = false.obs;

  // Stats
  final RxMap<String, dynamic> stats = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchExams();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      final response = await _apiService.get('/teacher/dashboard/stats');
      if (response['success'] == true) {
        stats.value = response['data'];
      }
    } catch (e) {
      print('Failed to fetch stats: $e');
    }
  }

  Future<void> fetchExams() async {
    try {
      isLoading.value = true;
      final response = await _apiService.get('/teacher/exams');

      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        exams.value = data.map((json) => Exam.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error: $e');
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to load exams: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteExam(int examId) async {
    try {
      final response = await _apiService.delete('/teacher/exams/$examId');
      if (response['success'] == true) {
        exams.removeWhere((e) => e.id == examId);
        fetchStats(); // Update stats on delete
        Get.defaultDialog(
          title: 'Success',
          middleText: 'Exam deleted successfully',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      } else {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'Failed to delete exam',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to delete exam: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
  }
}
