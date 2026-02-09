import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/create_exam_controller.dart';
import '../../utils/app_colors.dart';
import '../../data/models/exam_model.dart';
import 'package:intl/intl.dart';

class CreateExamScreen extends StatelessWidget {
  final Exam? exam; // Optional exam for editing

  const CreateExamScreen({super.key, this.exam});

  @override
  Widget build(BuildContext context) {
    // Initialize controller with optional exam
    final CreateExamController controller = Get.put(CreateExamController());
    if (exam != null) {
      controller.setExamForEditing(exam!);
    } else {
      controller.resetFields();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(exam != null ? 'Edit Exam' : 'Create New Exam'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller.titleController,
              decoration: const InputDecoration(
                labelText: 'Exam Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Start Time:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Obx(
              () => _buildDateTimePickers(
                context,
                controller.startTime,
                (val) => controller.startTime.value = val,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'End Time:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Obx(
              () => _buildDateTimePickers(
                context,
                controller.endTime,
                (val) => controller.endTime.value = val,
              ),
            ),

            const SizedBox(height: 32),
            Obx(
              () => ElevatedButton(
                onPressed: controller.isLoading.value
                    ? null
                    : () => controller.submitExam(
                        isEditing: exam != null,
                        examId: exam?.id,
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: controller.isLoading.value
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        exam != null ? 'UPDATE EXAM' : 'CREATE EXAM',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePickers(
    BuildContext context,
    Rx<DateTime> dateTime,
    Function(DateTime) onUpdate,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(DateFormat('yyyy-MM-dd').format(dateTime.value)),
            onPressed: () async {
              DateTime? pick = await showDatePicker(
                context: context,
                initialDate: dateTime.value,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (pick != null) {
                final time = TimeOfDay.fromDateTime(dateTime.value);
                onUpdate(
                  DateTime(
                    pick.year,
                    pick.month,
                    pick.day,
                    time.hour,
                    time.minute,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(DateFormat('HH:mm').format(dateTime.value)),
            onPressed: () async {
              TimeOfDay? pick = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(dateTime.value),
              );
              if (pick != null) {
                final date = dateTime.value;
                onUpdate(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    pick.hour,
                    pick.minute,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
