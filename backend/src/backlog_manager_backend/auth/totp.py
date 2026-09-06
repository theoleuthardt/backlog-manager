import pyotp
from cryptography.fernet import Fernet

from backlog_manager_backend.config import settings

_ISSUER = "Backlog Manager"
_VALID_WINDOW = 1


def generate_secret() -> str:
    return pyotp.random_base32()


def build_otpauth_url(secret: str, email: str) -> str:
    return pyotp.totp.TOTP(secret).provisioning_uri(name=email, issuer_name=_ISSUER)


def verify_totp_code(secret: str, code: str) -> bool:
    return pyotp.TOTP(secret).verify(code, valid_window=_VALID_WINDOW)


def _fernet() -> Fernet:
    return Fernet(settings.totp_encryption_key.encode())


def encrypt_secret(secret: str) -> str:
    return _fernet().encrypt(secret.encode()).decode()


def decrypt_secret(encrypted_secret: str) -> str:
    return _fernet().decrypt(encrypted_secret.encode()).decode()
