const express = require('express');
const router = express.Router();
const AuthController = require('../controllers/auth.controller');

// Public routes
router.post('/login', AuthController.login);
router.post('/refresh-token', AuthController.refreshToken);

module.exports = router;