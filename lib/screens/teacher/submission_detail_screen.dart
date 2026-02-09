import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/grading_controller.dart';
import '../../utils/app_colors.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final int submissionId;

  const SubmissionDetailScreen({super.key, required this.submissionId});

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  late Future<Map<String, dynamic>?> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final controller = Get.find<GradingController>();
    setState(() {
      _detailsFuture = controller.fetchSubmissionDetails(widget.submissionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GradingController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Details'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final submissionData = snapshot.data;
          if (submissionData == null || submissionData['submission'] == null) {
            return const Center(child: Text('Failed to load submission data.'));
          }

          return _buildContent(submissionData, controller);
        },
      ),
    );
  }

  Widget _buildContent(
    Map<String, dynamic> submissionData,
    GradingController controller,
  ) {
    final submission = submissionData['submission'] ?? {};
    final List answers = submissionData['answers'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student: ${submission['student_name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Score: ${submission['total_score']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Answers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: answers.length,
            itemBuilder: (context, index) {
              final answer = answers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}: ${answer['question_text']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Answer: ${answer['answer_text']}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Score: ${answer['score'] ?? 0} / ${answer['points']}',
                            style: TextStyle(
                              color:
                                  (double.tryParse(
                                            (answer['score'] ?? 0).toString(),
                                          ) ??
                                          0) >
                                      0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Grade'),
                            onPressed: () => _showGradeDialog(
                              context,
                              controller,
                              answer['answer_id'],
                              int.tryParse(answer['points'].toString()) ?? 0,
                            ),
                          ),
                          if (answer['question_type'] == 'true_false' ||
                              answer['question_type'] == 'fill_blank')
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                '(Correct: ${answer['correct_answer']})',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showGradeDialog(
    BuildContext context,
    GradingController controller,
    int answerId,
    int maxPoints,
  ) {
    final scoreController = TextEditingController();
    Get.defaultDialog(
      title: 'Grade Answer',
      content: Column(
        children: [
          Text('Enter score (Max: $maxPoints)'),
          TextField(
            controller: scoreController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Score'),
          ),
        ],
      ),
      textConfirm: 'Save',
      onConfirm: () async {
        final score = int.tryParse(scoreController.text);
        if (score != null && score <= maxPoints && score >= 0) {
          final success = await controller.gradeAnswer(answerId, score);
          if (success) {
            Get.back(); // close dialog
            Get.defaultDialog(
              title: 'Success',
              middleText: 'Grade saved successfully',
              textConfirm: 'OK',
              onConfirm: () {
                Get.back();
                _refresh();
              },
            );
          }
        } else {
          Get.defaultDialog(
            title: 'Error',
            middleText: 'Invalid score',
            textConfirm: 'OK',
            onConfirm: () => Get.back(),
          );
        }
      },
    );
  }
}
