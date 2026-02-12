import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/question_model.dart';
import '../data/services/api_service.dart';

class ExamTakingController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final int examId;

  ExamTakingController(this.examId);

  final RxBool isLoading = false.obs;
  final RxList<Question> questions = <Question>[].obs;
  final RxMap<int, dynamic> answers =
      <int, dynamic>{}.obs; // questionId -> answer

  // Timer logic could be added here if exam interaction details were more specific about duration enforcement from API
  // For now, we just allow taking it.

  @override
  void onInit() {
    super.onInit();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    try {
      isLoading.value = true;
      // Endpoint: GET /student/exams/{id}
      final response = await _apiService.get('/student/exams/$examId');

      if (response['success'] == true) {
        final data = response['data'];
        // The API might return the exam object with a 'questions' field, or just questions.
        // Based on "Get exam details + questions", let's assume structure.
        // Adjusting based on typical API response for details
        if (data['questions'] != null) {
          final List<dynamic> qList = data['questions'];
          questions.value = qList.map((q) => Question.fromJson(q)).toList();
        }
      }
    } catch (e) {
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

  void updateAnswer(int questionId, dynamic answer) {
    answers[questionId] = answer;
  }

  Future<void> submitExam() async {
    try {
      isLoading.value = true;

      final List<Map<String, dynamic>> submissions = [];
      answers.forEach((qId, ans) {
        submissions.add({'question_id': qId, 'answer_text': ans.toString()});
      });

      final response = await _apiService.post('/student/submit-answers', {
        'exam_id': examId,
        'answers': submissions,
      });

      if (response['success'] == true) {
        final data = response['data'];
        final totalScore = data['totalScore'];
        final gradingStatus = data['gradingStatus'];

        String title = 'Exam Submitted!';
        String message = 'Great job completing the exam!';
        String scoreLabel = 'Your Score: $totalScore';

        if (gradingStatus == 'pending') {
          title = 'Submission Received';
          scoreLabel = 'Preliminary Score: $totalScore';
          message =
              'Some questions require manual grading.\nYour final score will be updated after teacher review.';
        }

        Get.defaultDialog(
          title: title,
          content: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              Text(
                scoreLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          textConfirm: 'Back to Home',
          confirmTextColor: Colors.white,
          onConfirm: () {
            Get.back(); // close dialog
            Get.offNamed('/student'); // Go back to dashboard
          },
          barrierDismissible: false,
        );
      } else {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'Submission failed',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      if (e.toString().contains('409')) {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'You have already submitted this exam.',
          textConfirm: 'OK',
          onConfirm: () => Get.offNamed('/student'),
        );
      } else {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'Failed to submit: $e',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }
}
