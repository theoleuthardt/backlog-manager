"""Guards the isolation between tests that commit real rows.

Route tests log users in through `create_and_login`, which commits them to
the session-shared database. Without cleanup, a later test that creates the
same username (the repo tests use fixed names like "entryowner") fails with a
unique violation - but only when the files run in a different order than
alphabetical. The two tests below rely on running in definition order."""

from litestar.testing import TestClient

_EMAIL = "fixtureisolation@example.com"


async def test_create_and_login_commits_a_real_user(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, _EMAIL)
        response = client.get("/api/user/me", headers=headers)

    assert response.status_code == 200


async def test_users_from_earlier_tests_are_cleaned_up(postgres_url: str, session) -> None:
    from backlog_manager_backend.repositories import user_repo

    assert await user_repo.get_user_by_email(session, _EMAIL) is None
