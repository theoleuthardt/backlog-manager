from cryptography.fernet import Fernet


def encrypt(value: str, key: str) -> str:
    return Fernet(key.encode()).encrypt(value.encode()).decode()


def decrypt(value: str, key: str) -> str:
    return Fernet(key.encode()).decrypt(value.encode()).decode()
