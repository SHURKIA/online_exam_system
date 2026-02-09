import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/teacher_controller.dart';
import '../../utils/app_colors.dart';
import '../../data/models/exam_model.dart';
import 'create_exam_screen.dart';
import 'manage_questions_screen.dart';
import 'grading_screen.dart';
import '../common/profile_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final TeacherController teacherController = Get.put(TeacherController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              teacherController.fetchExams();
              teacherController.fetchStats();
            },
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
                accountName: Text(user?.name ?? 'Teacher'),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    (user?.name ?? 'T')[0].toUpperCase(),
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
              leading: const Icon(Icons.assignment),
              title: const Text('Submissions'),
              onTap: () {
                Get.back();
                Get.to(() => const GradingScreen());
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const CreateExamScreen());
        },
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (teacherController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildStatsCards(teacherController.stats),
            Expanded(
              child: teacherController.exams.isEmpty
                  ? const Center(child: Text('No exams created yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: teacherController.exams.length,
                      itemBuilder: (context, index) {
                        final exam = teacherController.exams[index];
                        return _buildExamCard(exam, teacherController);
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    // Expected stats: {total_exams: x, total_questions: y} from API potentially
    // Let's check api response structure or assume simple keys
    // teacher-exam.controller.js implementation of getDashboardStats needs to be checked
    // or we display what we have.
    // Usually: totalExams, activeExams, totalStudents (maybe)
    final totalExams = stats['total_exams'] ?? 0;
    final totalQuestions = stats['total_questions'] ?? 0; // if available

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: _statCard('Total Exams', totalExams.toString(), Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'Total Questions',
              totalQuestions.toString(),
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildExamCard(Exam exam, TeacherController controller) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exam.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      controller.deleteExam(exam.id);
                    } else if (value == 'view') {
                      Get.to(
                        () => ManageQuestionsScreen(
                          examId: exam.id,
                          examTitle: exam.title,
                        ),
                      );
                    } else if (value == 'edit') {
                      Get.to(() => CreateExamScreen(exam: exam));
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return {'View', 'Edit', 'Delete'}.map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice.toLowerCase(),
                        child: Text(choice),
                      );
                    }).toList();
                  },
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}
