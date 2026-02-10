import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/grading_controller.dart';
import '../../utils/app_colors.dart';
import 'submission_detail_screen.dart';

class GradingScreen extends StatelessWidget {
  const GradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GradingController controller = Get.put(GradingController());

    return Scaffold(
      appBar: AppBar(title: const Text('Submissions')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.submissions.isEmpty) {
          return const Center(child: Text('No submissions found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.submissions.length,
          itemBuilder: (context, index) {
            final sub = controller.submissions[index];
            // Assuming structure based on typical join: { user: {name: ...}, exam: {title: ...}, score: ... }
            // If API returns flat, adjust. Safe navigation used.
            final studentName = sub['student_name'] ?? 'Unknown Student';
            final examTitle = sub['exam_title'] ?? 'Unknown Exam';
            final score = sub['total_score'] ?? 'Not Graded';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(studentName[0].toUpperCase()),
                ),
                title: Text(studentName),
                subtitle: Text(examTitle),
                trailing: Text(
                  'Score: $score',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  final rawId = sub['submission_id'] ?? sub['exam_id'] ?? sub['answer_id'];
                  if (rawId == null) {
                    Get.snackbar('Error', 'No submission id available');
                    return;
                  }
                  final id = int.tryParse(rawId.toString());
                  if (id == null) {
                    Get.snackbar('Error', 'Invalid submission id');
                    return;
                  }

                  Get.to(
                    () => SubmissionDetailScreen(
                      submissionId: id,
                    ),
                  );
                },
              ),
            );
          },
        );
      }),
    );
  }
}
