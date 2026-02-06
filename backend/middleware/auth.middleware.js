const jwt = require("jsonwebtoken");
const jwtConfig = require("../config/jwt");
const { pool } = require("../config/database");

// Blacklist for logged out tokens
const tokenBlacklist = new Set();

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: "Access token required",
    });
  }

  // Check if token is blacklisted
  if (tokenBlacklist.has(token)) {
    return res.status(401).json({
      success: false,
      message: "Token has been invalidated",
    });
  }

  jwt.verify(token, jwtConfig.secret, (err, decoded) => {
    if (err) {
      return res.status(403).json({
        success: false,
        message:
          err.name === "TokenExpiredError" ? "Token expired" : "Invalid token",
      });
    }

    req.user = decoded;
    next();
  });
};

// Middleware for student-only access
const requireStudent = (req, res, next) => {
  if (req.user.role !== "student") {
    return res.status(403).json({
      success: false,
      message: "Student access only",
    });
  }
  next();
};

// Middleware for teacher-only access
const requireTeacher = (req, res, next) => {
  if (req.user.role !== "teacher") {
    return res.status(403).json({
      success: false,
      message: "Teacher access only",
    });
  }
  next();
};

// Middleware for admin-only access
const requireAdmin = (req, res, next) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({
      success: false,
      message: "Admin access only",
    });
  }
  next();
};

const generateToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    },
    jwtConfig.secret,
    { expiresIn: jwtConfig.expiresIn },
  );
};

const generateRefreshToken = (user) => {
  return jwt.sign({ id: user.id }, jwtConfig.refreshSecret, {
    expiresIn: jwtConfig.refreshExpiresIn,
  });
};

const invalidateToken = (token) => {
  tokenBlacklist.add(token);
  setTimeout(
    () => {
      tokenBlacklist.delete(token);
    },
    24 * 60 * 60 * 1000,
  );
};

module.exports = {
  authenticateToken,
  requireStudent,
  requireTeacher,
  requireAdmin,
  generateToken,
  generateRefreshToken,
  invalidateToken,
};
