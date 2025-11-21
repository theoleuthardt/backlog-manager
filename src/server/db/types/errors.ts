import { TRPCError } from "@trpc/server";

/**
 * Custom database error class
 */
export class DatabaseError extends TRPCError {
  constructor(operation: string, cause: unknown) {
    const message = `Database operation failed: ${operation}`;
    super({
      code: "INTERNAL_SERVER_ERROR",
      message,
      cause,
    });
  }
}

/**
 * Error for when a resource is not found
 */
export class NotFoundError extends TRPCError {
  constructor(resource: string, identifier: string | number) {
    super({
      code: "NOT_FOUND",
      message: `${resource} with identifier ${identifier} not found`,
    });
  }
}

/**
 * Error for duplicate/conflicting resources
 */
export class ConflictError extends TRPCError {
  constructor(message: string) {
    super({
      code: "CONFLICT",
      message,
    });
  }
}

/**
 * Error for invalid input
 */
export class ValidationError extends TRPCError {
  constructor(message: string) {
    super({
      code: "BAD_REQUEST",
      message,
    });
  }
}

/**
 * Map PostgreSQL error codes to appropriate tRPC errors
 */
export function handleDatabaseError(error: unknown, operation: string): never {
  if (error && typeof error === 'object' && 'code' in error) {
    switch (error.code) {
      case "23505": // Unique violation
        throw new ConflictError(
          "A resource with this identifier already exists",
        );
      case "23503": // Foreign key violation
        throw new ValidationError("Referenced resource does not exist");
      case "23502": // Not null violation
        throw new ValidationError("Required field is missing");
      case "22P02": // Invalid text representation
        throw new ValidationError("Invalid data format");
      default:
        throw new DatabaseError(operation, error);
    }
  }

  throw new DatabaseError(operation, error);
}
