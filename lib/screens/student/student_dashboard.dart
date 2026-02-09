import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/student_controller.dart';
import '../../utils/app_colors.dart';
import '../../data/models/exam_model.dart';
import 'exam_taking_screen.dart';
import 'student_exam_result_screen.dart';
import '../common/profile_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final StudentController studentController = Get.put(StudentController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Exams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => studentController.fetchExams(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Obx(() {
              final user = authController.user.value;
              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primary),
                accountName: Text(user?.name ?? 'Student'),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    (user?.name ?? 'S')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40.0,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Get.back(); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Get.back();
                Get.to(() => const ProfileScreen());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                authController.logout();
              },
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (studentController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (studentController.exams.isEmpty) {
          return const Center(child: Text('No exams available.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: studentController.exams.length,
          itemBuilder: (context, index) {
            final exam = studentController.exams[index];
            return _buildExamCard(exam);
          },
        );
      }),
    );
  }

  Widget _buildExamCard(Exam exam) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(exam.description),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Start: ${exam.startTime.toLocal().toString().split('.')[0]}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: exam.isSubmitted
                  ? Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Exam Submitted',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (exam.totalScore != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Score: ${exam.totalScore}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Get.to(
                              () => StudentExamResultScreen(examId: exam.id),
                            );
                          },
                          icon: const Icon(Icons.bar_chart),
                          label: const Text('See Results & Feedback'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () {
                        Get.to(
                          () => ExamTakingScreen(
                            examId: exam.id,
                            examTitle: exam.title,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Exam'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
