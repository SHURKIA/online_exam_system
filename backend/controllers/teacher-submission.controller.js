const { pool } = require("../config/database");

const TeacherSubmissionController = {
  // Get submissions for teacher's exams
  getSubmissions: async (req, res) => {
    try {
      const teacherId = req.user.id;
      const { exam_id, status } = req.query;

      let query = `
                SELECT 
                    a.id as answer_id,
                    a.answer_text,
                    a.score,
                    a.submitted_at,
                    q.id as question_id,
                    q.question_text,
                    q.question_type,
                    q.points,
                    q.correct_answer,
                    e.id as exam_id,
                    e.title as exam_title,
                    s.id as student_id,
                    s.name as student_name,
                    s.email as student_email,
                    CASE 
                        WHEN a.score IS NULL THEN 'pending'
                        ELSE 'graded'
                    END as grading_status
                FROM answers a
                JOIN questions q ON a.question_id = q.id
                JOIN exams e ON q.exam_id = e.id
                JOIN users s ON a.student_id = s.id
                WHERE e.teacher_id = ?
            `;

      const queryParams = [teacherId];

      // Add filters if provided
      if (exam_id) {
        query += " AND e.id = ?";
        queryParams.push(exam_id);
      }

      if (status === "pending") {
        query += " AND a.score IS NULL";
      } else if (status === "graded") {
        query += " AND a.score IS NOT NULL";
      }

      query += " ORDER BY a.submitted_at DESC LIMIT 100";

      const [submissions] = await pool.execute(query, queryParams);

      res.json({
        success: true,
        data: submissions,
      });
    } catch (error) {
      console.error("Get submissions error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Grade a submission
  gradeSubmission: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const answerId = req.params.id;
      const { score, feedback } = req.body;

      if (score === undefined) {
        return res.status(400).json({
          success: false,
          message: "Score is required",
        });
      }

      // Get answer with exam info
      const [answers] = await connection.execute(
        `
                SELECT a.*, q.points, e.teacher_id
                FROM answers a
                JOIN questions q ON a.question_id = q.id
                JOIN exams e ON q.exam_id = e.id
                WHERE a.id = ?
            `,
        [answerId],
      );

      if (answers.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Answer not found",
        });
      }

      const answer = answers[0];

      // Verify exam belongs to teacher
      if (answer.teacher_id !== teacherId) {
        await connection.rollback();
        return res.status(403).json({
          success: false,
          message: "Access denied",
        });
      }

      // Validate score
      const maxPoints = answer.points;
      if (score < 0 || score > maxPoints) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: `Score must be between 0 and ${maxPoints}`,
        });
      }

      // Update score
      await connection.execute("UPDATE answers SET score = ? WHERE id = ?", [
        score,
        answerId,
      ]);

      // Get updated answer
      const [updatedAnswers] = await connection.execute(
        `
                SELECT 
                    a.*,
                    q.question_text,
                    q.question_type,
                    q.points,
                    s.name as student_name
                FROM answers a
                JOIN questions q ON a.question_id = q.id
                JOIN users s ON a.student_id = s.id
                WHERE a.id = ?
            `,
        [answerId],
      );

      await connection.commit();

      res.json({
        success: true,
        message: "Submission graded successfully",
        data: updatedAnswers[0],
      });
    } catch (error) {
      await connection.rollback();
      console.error("Grade submission error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },

  // Get single submission details by answer id (returns all answers for that student's exam)
  getSubmissionDetails: async (req, res) => {
    try {
      const answerId = req.params.id;

      // Get the answer to determine student and exam
      const [answers] = await pool.execute(
        `
                SELECT a.*, q.exam_id, q.id as question_id, q.points, q.question_text, q.question_type, q.correct_answer, s.id as student_id, s.name as student_name, e.title as exam_title
                FROM answers a
                JOIN questions q ON a.question_id = q.id
                JOIN exams e ON q.exam_id = e.id
                JOIN users s ON a.student_id = s.id
                WHERE a.id = ?
            `,
        [answerId],
      );

      if (answers.length === 0) {
        return res.status(404).json({ success: false, message: 'Answer not found' });
      }

      const first = answers[0];
      const studentId = first.student_id;
      const examId = first.exam_id;

      // Fetch all answers for this student for the exam
      const [allAnswers] = await pool.execute(
        `
                SELECT a.id as answer_id, a.answer_text, a.score, a.submitted_at,
                       q.id as question_id, q.question_text, q.question_type, q.points, q.correct_answer
                FROM answers a
                JOIN questions q ON a.question_id = q.id
                WHERE a.student_id = ? AND q.exam_id = ?
                ORDER BY q.id
            `,
        [studentId, examId],
      );

      // Calculate total score (may be null values)
      const totalScore = allAnswers.reduce((acc, row) => acc + (row.score == null ? 0 : Number(row.score)), 0);

      const submission = {
        student_id: studentId,
        student_name: first.student_name,
        exam_id: examId,
        exam_title: first.exam_title,
        total_score: totalScore,
      };

      res.json({ success: true, data: { submission, answers: allAnswers } });
    } catch (error) {
      console.error('Get submission details error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  },

  // Get exam submissions summary
  getExamSubmissionsSummary: async (req, res) => {
    try {
      const teacherId = req.user.id;
      const examId = req.params.examId;

      // Verify exam belongs to teacher
      const [exams] = await pool.execute(
        "SELECT id FROM exams WHERE id = ? AND teacher_id = ?",
        [examId, teacherId],
      );

      if (exams.length === 0) {
        return res.status(404).json({
          success: false,
          message: "Exam not found or access denied",
        });
      }

      const [summary] = await pool.execute(
        `
                SELECT 
                    s.id as student_id,
                    s.name as student_name,
                    s.email as student_email,
                    COUNT(DISTINCT q.id) as total_questions,
                    COUNT(DISTINCT a.id) as answered_questions,
                    SUM(a.score) as total_score,
                    SUM(q.points) as max_possible_score,
                    ROUND((SUM(a.score) / SUM(q.points)) * 100, 2) as percentage,
                    COUNT(CASE WHEN a.score IS NULL THEN 1 END) as pending_grading
                FROM users s
                CROSS JOIN questions q ON q.exam_id = ?
                LEFT JOIN answers a ON q.id = a.question_id AND a.student_id = s.id
                WHERE EXISTS (
                    SELECT 1 FROM answers a2 
                    JOIN questions q2 ON a2.question_id = q2.id 
                    WHERE q2.exam_id = ? AND a2.student_id = s.id
                )
                GROUP BY s.id, s.name, s.email
                ORDER BY s.name
            `,
        [examId, examId],
      );

      res.json({
        success: true,
        data: summary,
      });
    } catch (error) {
      console.error("Get exam submissions summary error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Bulk grade submissions
  bulkGrade: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const { grades } = req.body; // Array of {answer_id, score}

      if (!Array.isArray(grades) || grades.length === 0) {
        return res.status(400).json({
          success: false,
          message: "Grades array is required",
        });
      }

      const results = [];
      const errors = [];

      for (const grade of grades) {
        try {
          const { answer_id, score } = grade;

          // Verify answer belongs to teacher's exam
          const [answers] = await connection.execute(
            `
                        SELECT a.*, q.points, e.teacher_id
                        FROM answers a
                        JOIN questions q ON a.question_id = q.id
                        JOIN exams e ON q.exam_id = e.id
                        WHERE a.id = ?
                    `,
            [answer_id],
          );

          if (answers.length === 0) {
            errors.push({
              answer_id,
              error: "Answer not found",
            });
            continue;
          }

          const answer = answers[0];

          if (answer.teacher_id !== teacherId) {
            errors.push({
              answer_id,
              error: "Access denied",
            });
            continue;
          }

          // Validate score
          if (score < 0 || score > answer.points) {
            errors.push({
              answer_id,
              error: `Score must be between 0 and ${answer.points}`,
            });
            continue;
          }

          // Update score
          await connection.execute(
            "UPDATE answers SET score = ? WHERE id = ?",
            [score, answer_id],
          );

          results.push({
            answer_id,
            success: true,
            score,
          });
        } catch (error) {
          errors.push({
            answer_id: grade.answer_id,
            error: error.message,
          });
        }
      }

      await connection.commit();

      res.json({
        success: true,
        message: "Bulk grading completed",
        data: {
          successful: results,
          errors: errors.length > 0 ? errors : undefined,
        },
      });
    } catch (error) {
      await connection.rollback();
      console.error("Bulk grade error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },
};

module.exports = TeacherSubmissionController;
