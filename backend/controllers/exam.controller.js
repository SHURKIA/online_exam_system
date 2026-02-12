const { pool } = require('../config/database');
const ExamUtil = require('../utils/exam.util');

const ExamController = {
    // Get all exams available for student
    getAvailableExams: async (req, res) => {
        try {
            const studentId = req.user.id;
            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');

            // Get exams that are currently active or upcoming
            const [exams] = await pool.execute(`
                SELECT e.*, 
                    u.name as teacher_name,
                    COUNT(DISTINCT q.id) as total_questions,
                    CASE 
                        WHEN ? < e.start_time THEN 'upcoming'
                        WHEN ? BETWEEN e.start_time AND e.end_time THEN 'active'
                        ELSE 'ended'
                    END as status,
                    CASE 
                        WHEN ? < e.start_time THEN TIMESTAMPDIFF(SECOND, ?, e.start_time)
                        WHEN ? BETWEEN e.start_time AND e.end_time THEN TIMESTAMPDIFF(SECOND, ?, e.end_time)
                        ELSE 0
                    END as time_remaining_seconds,
                    CASE WHEN es.id IS NOT NULL THEN TRUE ELSE FALSE END as is_submitted,
                    es.total_score
                FROM exams e
                LEFT JOIN users u ON e.teacher_id = u.id
                LEFT JOIN questions q ON e.id = q.exam_id
                LEFT JOIN exam_submissions es ON e.id = es.exam_id AND es.student_id = ?
                WHERE e.end_time >= ?
                GROUP BY e.id, es.id
                ORDER BY 
                    CASE 
                        WHEN e.start_time <= ? AND e.end_time >= ? THEN 0
                        WHEN e.start_time > ? THEN 1
                        ELSE 2
                    END,
                    e.start_time ASC
            `, [now, now, now, now, now, now, studentId, now, now, now, now]);

            res.json({
                success: true,
                data: exams
            });

        } catch (error) {
            console.error('Get exams error:', error);
            res.status(500).json({
                success: false,
                message: 'Internal server error'
            });
        }
    },

    // Get exam details with questions
    getExamDetails: async (req, res) => {
        try {
            const studentId = req.user.id;
            const examId = req.params.id;
            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');

            // Get exam details
            const [exams] = await pool.execute(`
                SELECT e.*, 
                    u.name as teacher_name,
                    CASE 
                        WHEN ? < e.start_time THEN 'upcoming'
                        WHEN ? BETWEEN e.start_time AND e.end_time THEN 'active'
                        ELSE 'ended'
                    END as status
                FROM exams e
                LEFT JOIN users u ON e.teacher_id = u.id
                WHERE e.id = ?
            `, [now, now, examId]);

            if (exams.length === 0) {
                return res.status(404).json({
                    success: false,
                    message: 'Exam not found'
                });
            }

            const exam = exams[0];

            // Check if student has submitted
            const [submissions] = await pool.execute(
                'SELECT id, total_score FROM exam_submissions WHERE exam_id = ? AND student_id = ?',
                [examId, studentId]
            );
            const isSubmitted = submissions.length > 0;

            if (isSubmitted) {
                exam.total_score = submissions[0].total_score;
            }

            // Check if student can access this exam
            if (ExamUtil.hasExamEnded(exam.end_time) || isSubmitted) {
                // Get questions with correct answers (after exam ended OR after submission)
                const [questions] = await pool.execute(`
                    SELECT q.*
                    FROM questions q
                    WHERE q.exam_id = ?
                    ORDER BY q.id ASC
                `, [examId]);

                exam.questions = questions;
            } else if (ExamUtil.isExamActive(exam.start_time, exam.end_time)) {
                // Get questions without correct answers (during exam and NOT submitted)
                const [questions] = await pool.execute(`
                    SELECT q.id, q.exam_id, q.question_text, q.question_type, q.points
                    FROM questions q
                    WHERE q.exam_id = ?
                    ORDER BY q.id ASC
                `, [examId]);

                exam.questions = questions;
            } else {
                // Exam is upcoming - return basic info only
                exam.questions = [];
            }

            // Get student's submitted answers if available (for both active/submitted and ended)
            if (isSubmitted || ExamUtil.isExamActive(exam.start_time, exam.end_time) || ExamUtil.hasExamEnded(exam.end_time)) {
                const [submittedAnswers] = await pool.execute(`
                    SELECT a.question_id, a.answer_text, a.score, a.submitted_at
                    FROM answers a
                    JOIN questions q ON a.question_id = q.id
                    WHERE a.student_id = ? AND q.exam_id = ?
                `, [studentId, examId]);

                exam.submitted_answers = submittedAnswers.reduce((acc, answer) => {
                    acc[answer.question_id] = answer;
                    return acc;
                }, {});
            }

            res.json({
                success: true,
                data: exam
            });

        } catch (error) {
            console.error('Get exam details error:', error);
            res.status(500).json({
                success: false,
                message: 'Internal server error'
            });
        }
    },

    // Get student's exam results
    getStudentResults: async (req, res) => {
        try {
            const studentId = req.user.id;

            const [results] = await pool.execute(`
                SELECT 
                    e.id as exam_id,
                    e.title,
                    e.start_time,
                    e.end_time,
                    COUNT(DISTINCT q.id) as total_questions,
                    SUM(q.points) as total_points,
                    COUNT(DISTINCT a.id) as answered_questions,
                    SUM(a.score) as obtained_score,
                    GROUP_CONCAT(DISTINCT q.question_type) as question_types
                FROM exams e
                LEFT JOIN questions q ON e.id = q.exam_id
                LEFT JOIN answers a ON q.id = a.question_id AND a.student_id = ?
                WHERE e.end_time < NOW()
                GROUP BY e.id
                ORDER BY e.end_time DESC
            `, [studentId]);

            res.json({
                success: true,
                data: results
            });

        } catch (error) {
            console.error('Get results error:', error);
            res.status(500).json({
                success: false,
                message: 'Internal server error'
            });
        }
    }
};

module.exports = ExamController;