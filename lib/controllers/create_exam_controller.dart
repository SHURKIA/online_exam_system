import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/services/api_service.dart';
import '../controllers/teacher_controller.dart';
import '../data/models/exam_model.dart';

class CreateExamController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final TeacherController _teacherController = Get.find<TeacherController>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  Rx<DateTime> startTime = DateTime.now().obs;
  Rx<DateTime> endTime = DateTime.now().add(const Duration(hours: 1)).obs;

  final RxBool isLoading = false.obs;

  void resetFields() {
    titleController.clear();
    descriptionController.clear();
    startTime.value = DateTime.now();
    endTime.value = DateTime.now().add(const Duration(hours: 1));
  }

  void setExamForEditing(Exam exam) {
    titleController.text = exam.title;
    descriptionController.text = exam.description;
    startTime.value = exam.startTime;
    endTime.value = exam.endTime;
  }

  Future<void> submitExam({bool isEditing = false, int? examId}) async {
    if (titleController.text.isEmpty) {
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Title is required',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
      return;
    }

    try {
      isLoading.value = true;
      final body = {
        'title': titleController.text,
        'description': descriptionController.text,
        'start_time': startTime.value.toIso8601String(),
        'end_time': endTime.value.toIso8601String(),
      };

      dynamic response;
      if (isEditing && examId != null) {
        response = await _apiService.put('/teacher/exams/$examId', body);
      } else {
        response = await _apiService.post('/teacher/exams', body);
      }

      if (response['success'] == true) {
        Get.back(); // Close screen
        Get.defaultDialog(
          title: 'Success',
          middleText: isEditing ? 'Exam updated' : 'Exam created',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
        _teacherController.fetchExams(); // Refresh list
      } else {
        Get.defaultDialog(
          title: 'Error',
          middleText: 'Failed to save exam',
          textConfirm: 'OK',
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      Get.defaultDialog(
        title: 'Error',
        middleText: 'Failed to save exam: $e',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
