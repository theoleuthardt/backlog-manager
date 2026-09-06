import secrets

_BACKUP_CODE_COUNT = 10


def generate_backup_codes(count: int = _BACKUP_CODE_COUNT) -> list[str]:
    codes = []
    for _ in range(count):
        raw = secrets.token_hex(4)
        codes.append(f"{raw[:4]}-{raw[4:]}")
    return codes
