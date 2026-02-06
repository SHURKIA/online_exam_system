const { pool } = require("../config/database");

const TeacherExamController = {
  // Get all exams for teacher with statistics
  getExams: async (req, res) => {
    try {
      const teacherId = req.user.id;

      const [exams] = await pool.execute(
        `
                SELECT 
                    e.*,
                    COUNT(DISTINCT q.id) as question_count,
                    COUNT(DISTINCT a.student_id) as student_count,
                    SUM(CASE WHEN a.score IS NOT NULL THEN 1 ELSE 0 END) as graded_answers,
                    SUM(CASE WHEN a.score IS NULL AND a.id IS NOT NULL THEN 1 ELSE 0 END) as pending_grading,
                    CASE 
                        WHEN NOW() < e.start_time THEN 'upcoming'
                        WHEN NOW() > e.end_time THEN 'ended'
                        ELSE 'active'
                    END as status,
                    TIMESTAMPDIFF(MINUTE, NOW(), e.end_time) as minutes_remaining
                FROM exams e
                LEFT JOIN questions q ON e.id = q.exam_id
                LEFT JOIN answers a ON q.id = a.question_id
                WHERE e.teacher_id = ?
                GROUP BY e.id
                ORDER BY e.created_at DESC
            `,
        [teacherId],
      );

      res.json({
        success: true,
        data: exams,
      });
    } catch (error) {
      console.error("Get teacher exams error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Create new exam
  createExam: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const { title, description, start_time, end_time } = req.body;

      // Validate required fields
      if (!title || !start_time || !end_time) {
        return res.status(400).json({
          success: false,
          message: "Title, start_time, and end_time are required",
        });
      }

      // Validate dates
      const startTime = new Date(start_time);
      const endTime = new Date(end_time);
      const now = new Date();

      if (startTime >= endTime) {
        return res.status(400).json({
          success: false,
          message: "End time must be after start time",
        });
      }

      // Insert exam
      const [result] = await connection.execute(
        `
                INSERT INTO exams (title, description, teacher_id, start_time, end_time)
                VALUES (?, ?, ?, ?, ?)
            `,
        [title, description || null, teacherId, start_time, end_time],
      );

      const examId = result.insertId;

      // Get the created exam
      const [exams] = await connection.execute(
        "SELECT * FROM exams WHERE id = ?",
        [examId],
      );

      await connection.commit();

      res.status(201).json({
        success: true,
        message: "Exam created successfully",
        data: exams[0],
      });
    } catch (error) {
      await connection.rollback();
      console.error("Create exam error:", error);

      if (error.code === "ER_TRUNCATED_WRONG_VALUE") {
        return res.status(400).json({
          success: false,
          message: "Invalid date format. Use YYYY-MM-DD HH:MM:SS",
        });
      }

      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },

  // Get single exam with questions
  getExamDetails: async (req, res) => {
    try {
      const teacherId = req.user.id;
      const examId = req.params.id;

      // Verify exam belongs to teacher
      const [exams] = await pool.execute(
        "SELECT * FROM exams WHERE id = ? AND teacher_id = ?",
        [examId, teacherId],
      );

      if (exams.length === 0) {
        return res.status(404).json({
          success: false,
          message: "Exam not found or access denied",
        });
      }

      const exam = exams[0];

      // Get questions for this exam
      const [questions] = await pool.execute(
        "SELECT * FROM questions WHERE exam_id = ? ORDER BY id ASC",
        [examId],
      );

      exam.questions = questions;

      // Get submission statistics
      const [stats] = await pool.execute(
        `
                SELECT 
                    COUNT(DISTINCT a.student_id) as total_students,
                    COUNT(DISTINCT q.id) as total_questions,
                    COUNT(DISTINCT a.id) as total_submissions,
                    AVG(a.score) as average_score
                FROM questions q
                LEFT JOIN answers a ON q.id = a.question_id
                WHERE q.exam_id = ?
            `,
        [examId],
      );

      exam.statistics = stats[0];

      res.json({
        success: true,
        data: exam,
      });
    } catch (error) {
      console.error("Get exam details error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Update exam
  updateExam: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const examId = req.params.id;
      const { title, description, start_time, end_time } = req.body;

      // Verify exam belongs to teacher
      const [exams] = await connection.execute(
        "SELECT * FROM exams WHERE id = ? AND teacher_id = ?",
        [examId, teacherId],
      );

      if (exams.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Exam not found or access denied",
        });
      }

      // Check if exam has started
      const exam = exams[0];
      const now = new Date();
      const examStartTime = new Date(exam.start_time);

      if (now > examStartTime) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "Cannot modify exam after it has started",
        });
      }

      // Prepare update fields
      const updateFields = [];
      const updateValues = [];

      if (title !== undefined) {
        updateFields.push("title = ?");
        updateValues.push(title);
      }
      if (description !== undefined) {
        updateFields.push("description = ?");
        updateValues.push(description);
      }
      if (start_time !== undefined) {
        updateFields.push("start_time = ?");
        updateValues.push(start_time);
      }
      if (end_time !== undefined) {
        updateFields.push("end_time = ?");
        updateValues.push(end_time);
      }

      if (updateFields.length === 0) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "No fields to update",
        });
      }

      // Add examId to values
      updateValues.push(examId);
      updateValues.push(teacherId);

      // Update exam
      await connection.execute(
        `UPDATE exams SET ${updateFields.join(", ")} WHERE id = ? AND teacher_id = ?`,
        updateValues,
      );

      // Get updated exam
      const [updatedExams] = await connection.execute(
        "SELECT * FROM exams WHERE id = ?",
        [examId],
      );

      await connection.commit();

      res.json({
        success: true,
        message: "Exam updated successfully",
        data: updatedExams[0],
      });
    } catch (error) {
      await connection.rollback();
      console.error("Update exam error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },

  // Delete exam
  deleteExam: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const examId = req.params.id;

      // Verify exam belongs to teacher
      const [exams] = await connection.execute(
        "SELECT * FROM exams WHERE id = ? AND teacher_id = ?",
        [examId, teacherId],
      );

      if (exams.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Exam not found or access denied",
        });
      }

      // Check if exam has started
      const exam = exams[0];
      const now = new Date();
      const examStartTime = new Date(exam.start_time);

      if (now > examStartTime) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "Cannot delete exam after it has started",
        });
      }

      // Delete exam (cascade will delete questions and answers)
      await connection.execute(
        "DELETE FROM exams WHERE id = ? AND teacher_id = ?",
        [examId, teacherId],
      );

      await connection.commit();

      res.json({
        success: true,
        message: "Exam deleted successfully",
      });
    } catch (error) {
      await connection.rollback();
      console.error("Delete exam error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },

  // Get teacher dashboard statistics
  getDashboardStats: async (req, res) => {
    try {
      const teacherId = req.user.id;

      const [stats] = await pool.execute(
        `
                SELECT 
                    COUNT(DISTINCT e.id) as total_exams,
                    COUNT(DISTINCT CASE WHEN NOW() < e.start_time THEN e.id END) as upcoming_exams,
                    COUNT(DISTINCT CASE WHEN NOW() BETWEEN e.start_time AND e.end_time THEN e.id END) as active_exams,
                    COUNT(DISTINCT CASE WHEN NOW() > e.end_time THEN e.id END) as ended_exams,
                    COUNT(DISTINCT q.id) as total_questions,
                    COUNT(DISTINCT a.student_id) as total_students,
                    COUNT(DISTINCT a.id) as total_submissions,
                    COUNT(DISTINCT CASE WHEN a.score IS NOT NULL THEN a.id END) as graded_submissions,
                    COUNT(DISTINCT CASE WHEN a.score IS NULL AND a.id IS NOT NULL THEN a.id END) as pending_grading
                FROM exams e
                LEFT JOIN questions q ON e.id = q.exam_id
                LEFT JOIN answers a ON q.id = a.question_id
                WHERE e.teacher_id = ?
            `,
        [teacherId],
      );

      res.json({
        success: true,
        data: stats[0],
      });
    } catch (error) {
      console.error("Get dashboard stats error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },
};

module.exports = TeacherExamController;
