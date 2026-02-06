class ExamUtil {
    // Check if exam is currently active
    static isExamActive(startTime, endTime) {
        const now = new Date();
        const start = new Date(startTime);
        const end = new Date(endTime);
        
        return now >= start && now <= end;
    }

    // Check if exam has ended
    static hasExamEnded(endTime) {
        const now = new Date();
        const end = new Date(endTime);
        
        return now > end;
    }

    // Check if exam is upcoming
    static isExamUpcoming(startTime) {
        const now = new Date();
        const start = new Date(startTime);
        
        return now < start;
    }

    // Calculate remaining time for exam
    static getRemainingTime(endTime) {
        const now = new Date();
        const end = new Date(endTime);
        
        if (now > end) return { expired: true, remaining: 0 };
        
        return {
            expired: false,
            remaining: Math.max(0, end - now)
        };
    }

    // Format exam status
    static getExamStatus(startTime, endTime) {
        if (this.isExamActive(startTime, endTime)) {
            return 'active';
        } else if (this.hasExamEnded(endTime)) {
            return 'ended';
        } else if (this.isExamUpcoming(startTime)) {
            return 'upcoming';
        }
        return 'unknown';
    }
}

module.exports = ExamUtil;