from sqlalchemy.exc import IntegrityError

# PostgreSQL SQLSTATE codes, mirroring the original TS pg-error-code switch.
_UNIQUE_VIOLATION = "23505"
_FOREIGN_KEY_VIOLATION = "23503"
_NOT_NULL_VIOLATION = "23502"
_INVALID_TEXT_REPRESENTATION = "22P02"


class DatabaseError(Exception):
    """Base error for unexpected database failures."""

    def __init__(self, operation: str, cause: object = None) -> None:
        message = f"Database operation failed: {operation}"
        if cause is not None:
            message += f" - {cause}"
        super().__init__(message)
        self.cause = cause


class NotFoundError(Exception):
    def __init__(self, resource: str, identifier: object) -> None:
        super().__init__(f"{resource} with identifier {identifier} not found")


class ConflictError(Exception):
    pass


class ValidationError(Exception):
    pass


def handle_database_error(error: Exception, operation: str) -> None:
    """Maps PostgreSQL errors (by SQLSTATE code) to the appropriate domain
    error and raises it. `error.orig` is SQLAlchemy's DBAPI-compatibility
    wrapper around the driver exception (not the raw asyncpg exception
    itself), but it exposes `.sqlstate` directly regardless of driver."""
    sqlstate = getattr(getattr(error, "orig", None), "sqlstate", None)

    if sqlstate == _UNIQUE_VIOLATION:
        raise ConflictError("A resource with this identifier already exists") from error
    if sqlstate == _FOREIGN_KEY_VIOLATION:
        raise ValidationError("Referenced resource does not exist") from error
    if sqlstate == _NOT_NULL_VIOLATION:
        raise ValidationError("Required field is missing") from error
    if sqlstate == _INVALID_TEXT_REPRESENTATION:
        raise ValidationError("Invalid data format") from error

    cause = error.orig if isinstance(error, IntegrityError) else error
    raise DatabaseError(operation, cause) from error
