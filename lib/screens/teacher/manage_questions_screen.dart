import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/manage_questions_controller.dart';
import '../../utils/app_colors.dart';

class ManageQuestionsScreen extends StatelessWidget {
  final int examId;
  final String examTitle;

  const ManageQuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  Widget build(BuildContext context) {
    final ManageQuestionsController controller = Get.put(
      ManageQuestionsController(examId),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Questions: $examTitle')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddQuestionDialog(context, controller),
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.questions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.questions.isEmpty) {
          return const Center(child: Text('No questions added yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.questions.length,
          itemBuilder: (context, index) {
            final question = controller.questions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(question.questionText),
                subtitle: Text(
                  'Type: ${question.type} | Points: ${question.points}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => controller.deleteQuestion(question.id),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _showAddQuestionDialog(
    BuildContext context,
    ManageQuestionsController controller,
  ) {
    final textController = TextEditingController();
    final pointsController = TextEditingController(text: '1');
    final correctAnsController = TextEditingController();
    String selectedType = 'true_false';

    Get.defaultDialog(
      title: 'Add Question',
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(labelText: 'Question Text'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              items: const [
                DropdownMenuItem(
                  value: 'true_false',
                  child: Text('True/False'),
                ),
                DropdownMenuItem(
                  value: 'fill_blank',
                  child: Text('Fill in Blank'),
                ),
                DropdownMenuItem(
                  value: 'short_answer',
                  child: Text('Short Answer'),
                ),
              ],
              onChanged: (val) => selectedType = val!,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(labelText: 'Points'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: correctAnsController,
              decoration: const InputDecoration(labelText: 'Correct Answer'),
            ),
          ],
        ),
      ),
      textConfirm: 'Add',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () {
        if (textController.text.isNotEmpty &&
            pointsController.text.isNotEmpty) {
          controller.addQuestion(
            textController.text,
            selectedType,
            int.tryParse(pointsController.text) ?? 1,
            correctAnsController.text,
          );
        }
      },
    );
  }
}
