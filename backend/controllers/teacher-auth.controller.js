const { pool } = require("../config/database");
const PasswordUtil = require("../utils/password.util");
const {
  generateToken,
  generateRefreshToken,
} = require("../middleware/auth.middleware");

const TeacherAuthController = {
  // Teacher Login
  login: async (req, res) => {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({
          success: false,
          message: "Email and password are required",
        });
      }

      // Find teacher by email
      const [users] = await pool.execute(
        "SELECT id, name, email, username, password, role FROM users WHERE email = ? AND role = ?",
        [email, "teacher"],
      );

      if (users.length === 0) {
        return res.status(401).json({
          success: false,
          message: "Invalid credentials or account not found",
        });
      }

      const user = users[0];

      // Verify password
      const isValidPassword = await PasswordUtil.verifyPassword(
        password,
        user.password,
      );

      if (!isValidPassword) {
        return res.status(401).json({
          success: false,
          message: "Invalid credentials",
        });
      }

      // Generate tokens
      const accessToken = generateToken(user);
      const refreshToken = generateRefreshToken(user);

      // Return user data (excluding password) and tokens
      const { password: _, ...userWithoutPassword } = user;

      res.json({
        success: true,
        message: "Login successful",
        data: {
          user: userWithoutPassword,
          tokens: {
            accessToken,
            refreshToken,
          },
        },
      });
    } catch (error) {
      console.error("Teacher login error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Get teacher profile
  getProfile: async (req, res) => {
    try {
      const teacherId = req.user.id;

      const [teachers] = await pool.execute(
        "SELECT id, name, email, username, role, created_at FROM users WHERE id = ? AND role = ?",
        [teacherId, "teacher"],
      );

      if (teachers.length === 0) {
        return res.status(404).json({
          success: false,
          message: "Teacher not found",
        });
      }

      res.json({
        success: true,
        data: teachers[0],
      });
    } catch (error) {
      console.error("Get teacher profile error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Teacher logout
  logout: async (req, res) => {
    try {
      const authHeader = req.headers["authorization"];
      const token = authHeader && authHeader.split(" ")[1];

      if (token) {
        const { invalidateToken } = require("../middleware/auth.middleware");
        invalidateToken(token);
      }

      res.json({
        success: true,
        message: "Logged out successfully",
      });
    } catch (error) {
      console.error("Teacher logout error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },
};

module.exports = TeacherAuthController;
