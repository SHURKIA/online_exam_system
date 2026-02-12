const { pool } = require("../config/database");

const TeacherSubmissionController = {
  // Get submissions for teacher's exams
  getSubmissions: async (req, res) => {
    try {
      const teacherId = req.user.id;
      const { exam_id, status } = req.query;

      let query = `
                SELECT 
                    es.id as submission_id,
                    es.total_score,
                    es.submitted_at,
                    e.id as exam_id,
                    e.title as exam_title,
                    s.id as student_id,
                    s.name as student_name,
                    s.email as student_email,
                    CASE 
                        WHEN EXISTS (
                            SELECT 1 FROM answers a 
                            JOIN questions q ON a.question_id = q.id 
                            WHERE a.student_id = es.student_id 
                            AND q.exam_id = es.exam_id 
                            AND a.score IS NULL
                        ) THEN 'pending'
                        ELSE 'graded'
                    END as grading_status
                FROM exam_submissions es
                JOIN exams e ON es.exam_id = e.id
                JOIN users s ON es.student_id = s.id
                WHERE e.teacher_id = ?
            `;

      const queryParams = [teacherId];

      // Add filters if provided
      if (exam_id) {
        query += " AND e.id = ?";
        queryParams.push(exam_id);
      }

      // Filter by status (computed in HAVING or subquery since it's complex)
      // Simplifying for performance: fetch all then filter in memory if needed, 
      // or use a simpler check. For now, let's just return all and let frontend filter 
      // or add a basic check if strictly required.

      query += ` ORDER BY es.submitted_at DESC LIMIT 100`;

      const [submissions] = await pool.execute(query, queryParams);

      // Manual filtering for status if requested (since alias in WHERE is tricky in MySQL depending on version)
      let filteredSubmissions = submissions;
      if (status) {
        filteredSubmissions = submissions.filter(s => s.grading_status === status);
      }

      res.json({
        success: true,
        data: filteredSubmissions,
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

      // Recalculate total score for the exam submission
      await connection.execute(`
          UPDATE exam_submissions es
          SET total_score = (
             SELECT SUM(a.score) 
             FROM answers a 
             JOIN questions q ON a.question_id = q.id 
             WHERE a.student_id = es.student_id AND q.exam_id = es.exam_id
          )
          WHERE es.student_id = ? AND es.exam_id = (SELECT exam_id FROM questions WHERE id = ?)
      `, [answer.student_id, answer.question_id]);

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

  // Get single submission details by submission_id
  getSubmissionDetails: async (req, res) => {
    try {
      const submissionId = req.params.id;

      // Get submission info
      const [submissions] = await pool.execute(
        `
            SELECT es.*, s.name as student_name, e.title as exam_title, e.teacher_id
            FROM exam_submissions es
            JOIN users s ON es.student_id = s.id
            JOIN exams e ON es.exam_id = e.id
            WHERE es.id = ?
        `,
        [submissionId]
      );

      if (submissions.length === 0) {
        return res
          .status(404)
          .json({ success: false, message: "Submission not found" });
      }

      const submission = submissions[0];

      // Verify teacher access
      if (submission.teacher_id !== req.user.id) {
        return res.status(403).json({ success: false, message: "Access denied" });
      }

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
        [submission.student_id, submission.exam_id],
      );

      // Recalculate total score to be fresh
      const totalScore = allAnswers.reduce(
        (acc, row) => acc + (row.score == null ? 0 : Number(row.score)),
        0,
      );

      const responseSubmission = {
        id: submission.id, // submission_id
        student_id: submission.student_id,
        student_name: submission.student_name,
        exam_id: submission.exam_id,
        exam_title: submission.exam_title,
        total_score: totalScore,
      };

      res.json({ success: true, data: { submission: responseSubmission, answers: allAnswers } });
    } catch (error) {
      console.error("Get submission details error:", error);
      res
        .status(500)
        .json({ success: false, message: "Internal server error" });
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
