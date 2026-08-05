/**
 * Structured application error that carries an HTTP status code.
 *
 * Throw this from any service when the error is a known domain error
 * (e.g. "OTP expired", "Booking not found") rather than an unexpected
 * system failure.  The global error handler will use the statusCode and
 * message instead of falling back to 500 "Internal server error".
 */
export class AppError extends Error {
  readonly statusCode: number;

  constructor(statusCode: number, message: string) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    // Maintain proper prototype chain for instanceof checks.
    Object.setPrototypeOf(this, AppError.prototype);
  }

  /** 400 Bad Request */
  static badRequest(message: string): AppError {
    return new AppError(400, message);
  }

  /** 401 Unauthorized */
  static unauthorized(message: string): AppError {
    return new AppError(401, message);
  }

  /** 403 Forbidden */
  static forbidden(message: string): AppError {
    return new AppError(403, message);
  }

  /** 404 Not Found */
  static notFound(message: string): AppError {
    return new AppError(404, message);
  }

  /** 409 Conflict */
  static conflict(message: string): AppError {
    return new AppError(409, message);
  }

  /** 410 Gone */
  static gone(message: string): AppError {
    return new AppError(410, message);
  }
}
