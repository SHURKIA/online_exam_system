const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth.middleware');
const ExamController = require('../controllers/exam.controller');
const AuthController = require('../controllers/auth.controller');

// All student routes require authentication
router.use(authenticateToken);

// Auth routes
router.get('/profile', AuthController.getProfile);

// Exam routes
router.get('/exams', ExamController.getAvailableExams);
router.get('/exams/:id', ExamController.getExamDetails);


module.exports = router;