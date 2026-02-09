class Question {
  final int id;
  final int examId;
  final String questionText;
  final String type; // true_false, fill_blank, short_answer
  final int points;
  final String?
  correctAnswer; 

  Question({
    required this.id,
    required this.examId,
    required this.questionText,
    required this.type,
    required this.points,
    this.correctAnswer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      examId: json['exam_id'],
      questionText: json['question_text'],
      type: json['question_type'],
      points: json['points'],
      // API might not send correct_answer to student, check this later
      correctAnswer: json['correct_answer'],
    );
  }
}
