const express = require("express");
const router = express.Router();
const {
  authenticateToken,
  requireTeacher,
} = require("../middleware/auth.middleware");

// Import controllers
const TeacherAuthController = require("../controllers/teacher-auth.controller");
const TeacherExamController = require("../controllers/teacher-exam.controller");
const TeacherQuestionController = require("../controllers/teacher-question.controller");

// Public routes (no auth required)
router.post("/login", TeacherAuthController.login);

// All routes below require teacher authentication
router.use(authenticateToken);
router.use(requireTeacher);

// Auth routes
router.get("/profile", TeacherAuthController.getProfile);
router.post("/logout", TeacherAuthController.logout);

// Dashboard
router.get("/dashboard/stats", TeacherExamController.getDashboardStats);

// Exam routes
router.get("/exams", TeacherExamController.getExams);
router.post("/exams", TeacherExamController.createExam);
router.get("/exams/:id", TeacherExamController.getExamDetails);
router.put("/exams/:id", TeacherExamController.updateExam);
router.delete("/exams/:id", TeacherExamController.deleteExam);

// Question routes
router.get(
  "/exams/:examId/questions",
  TeacherQuestionController.getExamQuestions,
);
router.post("/exams/:examId/questions", TeacherQuestionController.addQuestion);
router.put("/questions/:id", TeacherQuestionController.updateQuestion);
router.delete("/questions/:id", TeacherQuestionController.deleteQuestion);

module.exports = router;
