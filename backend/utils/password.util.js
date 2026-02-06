// Use bcryptjs instead of bcrypt
const bcrypt = require('bcryptjs');

class PasswordUtil {
    // Hash password (compatible with PHP's password_hash)
    static async hashPassword(password) {
        const saltRounds = parseInt(process.env.BCRYPT_SALT_ROUNDS) || 10;
        return await bcrypt.hash(password, saltRounds);
    }

    // Verify password against hash
    static async verifyPassword(password, hash) {
        try {
            // bcryptjs supports $2y$ format
            return await bcrypt.compare(password, hash);
        } catch (error) {
            console.error('Password verification error:', error);
            return false;
        }
    }

    // Check if hash is using bcrypt
    static isBcryptHash(hash) {
        return hash.startsWith('$2');
    }
}

module.exports = PasswordUtil;