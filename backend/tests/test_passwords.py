from backlog_manager_backend.auth.passwords import hash_password, verify_password


def test_hash_password_produces_argon2id_hash() -> None:
    hashed = hash_password("correct horse battery staple")

    assert hashed.startswith("$argon2id$")


def test_verify_password_accepts_correct_password() -> None:
    hashed = hash_password("correct horse battery staple")

    assert verify_password(hashed, "correct horse battery staple") is True


def test_verify_password_rejects_wrong_password() -> None:
    hashed = hash_password("correct horse battery staple")

    assert verify_password(hashed, "wrong password") is False


def test_verify_password_rejects_empty_hash() -> None:
    """OAuth-only accounts are created with password_hash="" and can
    never authenticate via credentials."""
    assert verify_password("", "anything") is False


def test_verify_password_rejects_malformed_hash() -> None:
    assert verify_password("not-a-real-hash", "anything") is False


def test_verify_password_accepts_node_argon2_hash() -> None:
    """Cross-compatibility with the existing Node `argon2` package's
    default output - both use the same PHC-format argon2id string, and
    argon2-cffi reads the parameters from the hash itself rather than
    requiring them to match its own configured defaults."""
    node_hash = (
        "$argon2id$v=19$m=65536,t=3,p=4$KxmKfVYzTdmgl9HiyPdv+A$"
        "anQyDoeP96ALidgJUuP3R+VLzIF+KwQ2kMEIKT3mNb8"
    )

    assert verify_password(node_hash, "correct horse battery staple") is True
