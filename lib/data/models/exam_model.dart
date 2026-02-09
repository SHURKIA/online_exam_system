class Exam {
  final int id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final int? teacherId;
  final bool isSubmitted;
  final double? totalScore;

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.teacherId,
    this.isSubmitted = false,
    this.totalScore,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      teacherId: json['teacher_id'],
      isSubmitted: json['is_submitted'] == 1 || json['is_submitted'] == true,
      totalScore: json['total_score'] != null
          ? double.tryParse(json['total_score'].toString())
          : null,
    );
  }
}
