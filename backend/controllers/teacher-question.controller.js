const { pool } = require("../config/database");

const TeacherQuestionController = {
  // Get questions for an exam
  getExamQuestions: async (req, res) => {
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

      const [questions] = await pool.execute(
        "SELECT * FROM questions WHERE exam_id = ? ORDER BY id ASC",
        [examId],
      );

      res.json({
        success: true,
        data: questions,
      });
    } catch (error) {
      console.error("Get exam questions error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Add question to exam
  addQuestion: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const examId = req.params.examId;
      const { question_text, question_type, points, correct_answer } = req.body;

      // Validate required fields
      if (!question_text || !question_type) {
        return res.status(400).json({
          success: false,
          message: "Question text and type are required",
        });
      }

      // Validate question type
      const validTypes = ["true_false", "fill_blank", "short_answer"];
      if (!validTypes.includes(question_type)) {
        return res.status(400).json({
          success: false,
          message:
            "Invalid question type. Must be: true_false, fill_blank, or short_answer",
        });
      }

      // Validate true/false answer
      if (question_type === "true_false" && correct_answer) {
        if (!["true", "false"].includes(correct_answer.toLowerCase())) {
          return res.status(400).json({
            success: false,
            message:
              'For true/false questions, correct answer must be "true" or "false"',
          });
        }
      }

      // Verify exam belongs to teacher and hasn't started
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

      const exam = exams[0];
      const now = new Date();
      const examStartTime = new Date(exam.start_time);

      if (now > examStartTime) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "Cannot add questions to exam after it has started",
        });
      }

      // Insert question
      const [result] = await connection.execute(
        `
                INSERT INTO questions (exam_id, question_text, question_type, points, correct_answer)
                VALUES (?, ?, ?, ?, ?)
            `,
        [
          examId,
          question_text,
          question_type,
          points || 1,
          correct_answer || null,
        ],
      );

      const questionId = result.insertId;

      // Get the created question
      const [questions] = await connection.execute(
        "SELECT * FROM questions WHERE id = ?",
        [questionId],
      );

      await connection.commit();

      res.status(201).json({
        success: true,
        message: "Question added successfully",
        data: questions[0],
      });
    } catch (error) {
      await connection.rollback();
      console.error("Add question error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },

  // Update question
  updateQuestion: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const questionId = req.params.id;
      const { question_text, question_type, points, correct_answer } = req.body;

      // Get question with exam info
      const [questions] = await connection.execute(
        `
                SELECT q.*, e.teacher_id, e.start_time
                FROM questions q
                JOIN exams e ON q.exam_id = e.id
                WHERE q.id = ?
            `,
        [questionId],
      );

      if (questions.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Question not found",
        });
      }

      const question = questions[0];

      // Verify exam belongs to teacher
      if (question.teacher_id !== teacherId) {
        await connection.rollback();
        return res.status(403).json({
          success: false,
          message: "Access denied",
        });
      }

      // Check if exam has started
      const now = new Date();
      const examStartTime = new Date(question.start_time);

      if (now > examStartTime) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "Cannot modify questions after exam has started",
        });
      }

      // Prepare update fields
      const updateFields = [];
      const updateValues = [];

      if (question_text !== undefined) {
        updateFields.push("question_text = ?");
        updateValues.push(question_text);
      }
      if (question_type !== undefined) {
        // Validate question type
        const validTypes = ["true_false", "fill_blank", "short_answer"];
        if (!validTypes.includes(question_type)) {
          await connection.rollback();
          return res.status(400).json({
            success: false,
            message: "Invalid question type",
          });
        }
        updateFields.push("question_type = ?");
        updateValues.push(question_type);
      }
      if (points !== undefined) {
        updateFields.push("points = ?");
        updateValues.push(points);
      }
      if (correct_answer !== undefined) {
        updateFields.push("correct_answer = ?");
        updateValues.push(correct_answer);
      }

      if (updateFields.length === 0) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "No fields to update",
        });
      }

      // Add questionId to values
      updateValues.push(questionId);

      // Update question
      await connection.execute(
        `UPDATE questions SET ${updateFields.join(", ")} WHERE id = ?`,
        updateValues,
      );

      // Get updated question
      const [updatedQuestions] = await connection.execute(
        "SELECT * FROM questions WHERE id = ?",
        [questionId],
      );

      await connection.commit();

      res.json({
        success: true,
        message: "Question updated successfully",
        data: updatedQuestions[0],
      });
    } catch (error) {
      await connection.rollback();
      console.error("Update question error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },

  // Delete question
  deleteQuestion: async (req, res) => {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const teacherId = req.user.id;
      const questionId = req.params.id;

      // Get question with exam info
      const [questions] = await connection.execute(
        `
                SELECT q.*, e.teacher_id, e.start_time
                FROM questions q
                JOIN exams e ON q.exam_id = e.id
                WHERE q.id = ?
            `,
        [questionId],
      );

      if (questions.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Question not found",
        });
      }

      const question = questions[0];

      // Verify exam belongs to teacher
      if (question.teacher_id !== teacherId) {
        await connection.rollback();
        return res.status(403).json({
          success: false,
          message: "Access denied",
        });
      }

      // Check if exam has started
      const now = new Date();
      const examStartTime = new Date(question.start_time);

      if (now > examStartTime) {
        await connection.rollback();
        return res.status(400).json({
          success: false,
          message: "Cannot delete questions after exam has started",
        });
      }

      // Delete question
      await connection.execute("DELETE FROM questions WHERE id = ?", [
        questionId,
      ]);

      await connection.commit();

      res.json({
        success: true,
        message: "Question deleted successfully",
      });
    } catch (error) {
      await connection.rollback();
      console.error("Delete question error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    } finally {
      connection.release();
    }
  },
};

module.exports = TeacherQuestionController;
