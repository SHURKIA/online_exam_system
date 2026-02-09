import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/exam_taking_controller.dart';
import '../../utils/app_colors.dart';
import '../../data/models/question_model.dart';

class ExamTakingScreen extends StatelessWidget {
  final int examId;
  final String examTitle;

  const ExamTakingScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  Widget build(BuildContext context) {
    final ExamTakingController controller = Get.put(
      ExamTakingController(examId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(examTitle)),
      body: Obx(() {
        if (controller.isLoading.value && controller.questions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.questions.isEmpty) {
          return const Center(child: Text('No questions found for this exam.'));
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.questions.length,
                itemBuilder: (context, index) {
                  final question = controller.questions[index];
                  return _buildQuestionCard(question, controller, index + 1);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => _confirmSubmit(context, controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SUBMIT EXAM',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildQuestionCard(
    Question question,
    ExamTakingController controller,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.secondary,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${question.points} Points',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.questionText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildAnswerInput(question, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput(Question question, ExamTakingController controller) {
    // Handle different question types
    if (question.type == 'true_false') {
      return Obx(() {
        final currentAnswer = controller.answers[question.id];
        return Column(
          children: [
            RadioListTile<String>(
              title: const Text('True'),
              value: 'true',
              groupValue: currentAnswer?.toString(),
              activeColor: AppColors.primary,
              onChanged: (val) => controller.updateAnswer(question.id, val),
            ),
            RadioListTile<String>(
              title: const Text('False'),
              value: 'false',
              groupValue: currentAnswer?.toString(),
              activeColor: AppColors.primary,
              onChanged: (val) => controller.updateAnswer(question.id, val),
            ),
          ],
        );
      });
    } else if (question.type == 'fill_blank' ||
        question.type == 'short_answer') {
      return TextField(
        onChanged: (val) => controller.updateAnswer(question.id, val),
        decoration: const InputDecoration(
          hintText: 'Type your answer here...',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
    }
    return const Text('Unsupported question type');
  }

  void _confirmSubmit(BuildContext context, ExamTakingController controller) {
    Get.defaultDialog(
      title: 'Submit Exam?',
      middleText: 'Are you sure you want to finish and submit your answers?',
      textConfirm: 'Yes, Submit',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () {
        Get.back(); // Close dialog
        controller.submitExam();
      },
    );
  }
}
