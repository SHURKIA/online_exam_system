const { pool } = require("../config/database");
const PasswordUtil = require("../utils/password.util");
const {
  generateToken,
  generateRefreshToken,
} = require("../middleware/auth.middleware");

const AuthController = {
  // Student Login
  // Student Login - DEBUG VERSION
  login: async (req, res) => {
    try {
      const { email, password } = req.body;

      console.log("📧 Login attempt for email:", email);
      console.log(
        "🔑 Password received (first 3 chars):",
        password ? password.substring(0, 3) + "***" : "empty",
      );

      // Input validation
      if (!email || !password) {
        console.log("❌ Missing email or password");
        return res.status(400).json({
          success: false,
          message: "Email and password are required",
        });
      }

      // Find student by email
      console.log("🔍 Searching for user in database...");
      const [users] = await pool.execute(
        "SELECT id, name, email, username, password, role FROM users WHERE email = ?",
        [email],
      );

      console.log("📊 Database query result:", {
        foundUsers: users.length,
        user:
          users.length > 0
            ? {
                id: users[0].id,
                email: users[0].email,
                role: users[0].role,
                passwordHash: users[0].password.substring(0, 20) + "...",
              }
            : "No user found",
      });

      if (users.length === 0) {
        console.log("❌ No user found with email:", email);
        return res.status(401).json({
          success: false,
          message: "Invalid credentials or account not found",
        });
      }

      const user = users[0];

      // Check if user is a student
      if (user.role !== "student" && user.role !== "teacher") {
        console.log("⛔ User is not a student. Role:", user.role);
        return res.status(403).json({
          success: false,
          message: "Mobile login is only for students and teachers",
        });
      }

      // Debug password verification
      console.log("🔐 Verifying password...");
      console.log("📝 Hash algorithm check:", user.password.substring(0, 10));

      const isValidPassword = await PasswordUtil.verifyPassword(
        password,
        user.password,
      );

      console.log("✅ Password verification result:", isValidPassword);

      if (!isValidPassword) {
        console.log("❌ Password verification failed");
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

      console.log("🎉 Login successful for user:", user.email);

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
      console.error("🔥 Login error:", error);
      console.error("🔥 Error stack:", error.stack);
      res.status(500).json({
        success: false,
        message: "Internal server error",
        ...(process.env.NODE_ENV === "development" && { error: error.message }),
      });
    }
  },

  // Refresh Token
  refreshToken: async (req, res) => {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        return res.status(400).json({
          success: false,
          message: "Refresh token required",
        });
      }

      const jwt = require("jsonwebtoken");
      const jwtConfig = require("../config/jwt");

      jwt.verify(
        refreshToken,
        jwtConfig.refreshSecret,
        async (err, decoded) => {
          if (err) {
            return res.status(403).json({
              success: false,
              message: "Invalid refresh token",
            });
          }

          // Get user from database
          const [users] = await pool.execute(
            "SELECT id, name, email, username, role FROM users WHERE id = ? AND role = ?",
            [decoded.id, "student"],
          );

          if (users.length === 0) {
            return res.status(404).json({
              success: false,
              message: "User not found",
            });
          }

          const user = users[0];
          const newAccessToken = generateToken(user);

          res.json({
            success: true,
            data: {
              accessToken: newAccessToken,
            },
          });
        },
      );
    } catch (error) {
      console.error("Refresh token error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },

  // Get current user profile
  getProfile: async (req, res) => {
    try {
      const userId = req.user.id;

      const [users] = await pool.execute(
        "SELECT id, name, email, username, role, created_at FROM users WHERE id = ?",
        [userId],
      );

      if (users.length === 0) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      res.json({
        success: true,
        data: users[0],
      });
    } catch (error) {
      console.error("Get profile error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  },
};

module.exports = AuthController;
