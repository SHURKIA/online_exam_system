import 'package:get/get.dart';
import '../data/models/exam_model.dart';
import '../data/services/api_service.dart';

class StudentController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<Exam> exams = <Exam>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchExams();
  }

  Future<void> fetchExams() async {
    try {
      isLoading.value = true;
      final response = await _apiService.get('/student/exams');

      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        exams.value = data.map((json) => Exam.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching exams: $e');
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
}
