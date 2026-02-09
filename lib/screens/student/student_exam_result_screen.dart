import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';
import '../../data/services/api_service.dart';

class StudentExamResultScreen extends StatefulWidget {
  final int examId;

  const StudentExamResultScreen({super.key, required this.examId});

  @override
  State<StudentExamResultScreen> createState() =>
      _StudentExamResultScreenState();
}

class _StudentExamResultScreenState extends State<StudentExamResultScreen> {
  late Future<Map<String, dynamic>> _resultFuture;
  final ApiService _apiService = Get.find<ApiService>();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  void _loadResults() {
    setState(() {
      _resultFuture = _fetchResults();
    });
  }

  Future<Map<String, dynamic>> _fetchResults() async {
    final response = await _apiService.get('/student/exams/${widget.examId}');
    if (response['success'] == true) {
      return response['data'];
    }
    throw Exception(response['message'] ?? 'Failed to load results');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Results'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadResults),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final List questions = data['questions'] ?? [];
          final Map submittedAnswers = data['submitted_answers'] ?? {};
          final totalScore = data['total_score'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(data, totalScore),
                const SizedBox(height: 24),
                const Text(
                  'Question Review',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    final submitted =
                        submittedAnswers[q['id'].toString()] ??
                        submittedAnswers[q['id']] ??
                        {};
                    return _buildQuestionCard(index + 1, q, submitted);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map data, dynamic totalScore) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? 'Exam Result',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Your Total Score: ',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  '$totalScore',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map q, Map submitted) {
    final bool isCorrect =
        (double.tryParse((submitted['score'] ?? 0).toString()) ?? 0) > 0;
    final String studentAns = submitted['answer_text'] ?? '(No answer)';
    final String correctAns = q['correct_answer'] ?? '(Manual grading)';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question $index',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              q['question_text'] ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildAnswerRow(
              'Your Answer:',
              studentAns,
              isCorrect ? Colors.green : Colors.red,
            ),
            if (!isCorrect)
              _buildAnswerRow('Correct Answer:', correctAns, Colors.green),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCorrect ? 'Correct' : 'Incorrect',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Score: ${submitted['score'] ?? 0} / ${q['points']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
