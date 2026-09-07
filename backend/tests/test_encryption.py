from cryptography.fernet import Fernet

from backlog_manager_backend.auth.encryption import decrypt, encrypt


def test_encrypt_decrypt_roundtrip() -> None:
    key = Fernet.generate_key().decode()

    encrypted = encrypt("my-secret-value", key)

    assert encrypted != "my-secret-value"
    assert decrypt(encrypted, key) == "my-secret-value"
