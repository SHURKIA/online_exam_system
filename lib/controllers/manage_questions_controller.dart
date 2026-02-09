import 'package:get/get.dart';
import '../data/models/question_model.dart';
import '../data/services/api_service.dart';

class ManageQuestionsController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final int examId;

  ManageQuestionsController(this.examId);

  final RxList<Question> questions = <Question>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    try {
      isLoading.value = true;
      // Endpoint: GET /teacher/exams/{examId}/questions
      final response = await _apiService.get(
        '/teacher/exams/$examId/questions',
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        questions.value = data.map((json) => Question.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching questions: $e');
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to load questions: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addQuestion(
    String text,
    String type,
    int points,
    String correctAnswer,
  ) async {
    try {
      isLoading.value = true;
      final response = await _apiService
          .post('/teacher/exams/$examId/questions', {
            'question_text': text,
            'question_type': type,
            'points': points,
            'correct_answer': correctAnswer,
          });

      if (response['success'] == true) {
        Get.back(); // Close dialog
        Get.defaultDialog(
          title: 'Success',
          middleText: 'Question added',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
        fetchQuestions(); // Refresh
      } else {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'Failed to add question',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to add question: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteQuestion(int questionId) async {
    try {
      final response = await _apiService.delete(
        '/teacher/questions/$questionId',
      );
      if (response['success'] == true) {
        questions.removeWhere((q) => q.id == questionId);
        Get.defaultDialog(
          title: 'Success',
          middleText: 'Question deleted',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      } else {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'Failed to delete question',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to delete question: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
  }
}
