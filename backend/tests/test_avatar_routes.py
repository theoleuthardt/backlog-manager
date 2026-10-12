from litestar.testing import TestClient

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 64
WEBP = b"RIFF\x24\x00\x00\x00WEBPVP8 " + b"\x00" * 32
MAX_BYTES = 512 * 1024


def _put(client: TestClient, headers: dict, body: bytes, content_type: str = "image/png"):
    return client.put(
        "/api/user/avatar", headers={**headers, "Content-Type": content_type}, content=body
    )


def _me(client: TestClient, headers: dict) -> dict:
    return client.get("/api/user/me", headers=headers).json()


async def test_avatar_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        statuses = [
            client.put("/api/user/avatar", content=PNG).status_code,
            client.delete("/api/user/avatar").status_code,
            client.get("/api/user/1/avatar").status_code,
        ]

    assert statuses == [401] * 3


async def test_upload_stores_the_picture_and_marks_the_user(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatarown@example.com")
        before = _me(client, headers)
        uploaded = _put(client, headers, PNG)
        me = _me(client, headers)
        fetched = client.get(f"/api/user/{me['id']}/avatar", headers=headers)

    assert before["avatar_updated_at"] is None
    assert uploaded.status_code == 204
    assert me["avatar_updated_at"] is not None
    assert fetched.status_code == 200
    assert fetched.content == PNG
    assert fetched.headers["content-type"] == "image/png"
    assert "etag" in fetched.headers
    assert set(fetched.headers["cache-control"].split(", ")) == {"private", "no-cache"}


async def test_jpeg_and_webp_are_accepted_and_replace_the_picture(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatarswap@example.com")
        user_id = _me(client, headers)["id"]
        assert _put(client, headers, JPEG, "image/jpeg").status_code == 204
        first = client.get(f"/api/user/{user_id}/avatar", headers=headers)
        assert _put(client, headers, WEBP, "image/webp").status_code == 204
        second = client.get(f"/api/user/{user_id}/avatar", headers=headers)

    assert (first.content, first.headers["content-type"]) == (JPEG, "image/jpeg")
    assert (second.content, second.headers["content-type"]) == (WEBP, "image/webp")


async def test_a_type_that_is_not_allowed_is_refused(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatarsvg@example.com")
        svg = _put(client, headers, b"<svg xmlns='http://www.w3.org/2000/svg'/>", "image/svg+xml")
        me = _me(client, headers)

    assert svg.status_code == 400
    assert me["avatar_updated_at"] is None


async def test_bytes_that_are_not_the_declared_image_are_refused(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatarfake@example.com")
        as_png = _put(client, headers, b"<html>not an image</html>", "image/png")
        jpeg_as_png = _put(client, headers, JPEG, "image/png")

    assert as_png.status_code == 400
    assert jpeg_as_png.status_code == 400


async def test_a_picture_over_the_limit_is_refused(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatarbig@example.com")
        big = _put(client, headers, PNG + b"\x00" * MAX_BYTES)
        exact = _put(client, headers, PNG + b"\x00" * (MAX_BYTES - len(PNG)))

    assert big.status_code == 400
    assert exact.status_code == 204


async def test_delete_removes_the_picture(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatardel@example.com")
        user_id = _me(client, headers)["id"]
        _put(client, headers, PNG)
        deleted = client.delete("/api/user/avatar", headers=headers)
        again = client.delete("/api/user/avatar", headers=headers)
        fetched = client.get(f"/api/user/{user_id}/avatar", headers=headers)
        me = _me(client, headers)

    assert deleted.status_code == 204
    assert again.status_code == 204
    assert fetched.status_code == 404
    assert me["avatar_updated_at"] is None


async def test_a_stranger_cannot_read_the_picture_but_the_partner_can(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "avatarpic@example.com")
        partner = await create_and_login(client, "avatarpartner@example.com")
        stranger = await create_and_login(client, "avatarstranger@example.com")
        owner_id = _me(client, owner)["id"]
        _put(client, owner, PNG)

        before = client.get(f"/api/user/{owner_id}/avatar", headers=partner)
        client.post("/api/space/invitations", headers=owner, json={"username": "avatarpartner"})
        client.post("/api/space/invitations/accept", headers=partner)
        after = client.get(f"/api/user/{owner_id}/avatar", headers=partner)
        outsider = client.get(f"/api/user/{owner_id}/avatar", headers=stranger)
        members = client.get("/api/space", headers=partner).json()["members"]

    assert before.status_code == 404
    assert after.status_code == 200
    assert after.content == PNG
    assert outsider.status_code == 404
    by_name = {member["username"]: member for member in members}
    assert by_name["avatarpic"]["avatar_updated_at"] is not None
    assert by_name["avatarpic"]["user_id"] == owner_id
    assert by_name["avatarpartner"]["avatar_updated_at"] is None


async def test_deleting_the_account_removes_the_picture(
    postgres_url: str, create_and_login, session
) -> None:
    from sqlalchemy import select

    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.models.user_avatar import UserAvatar

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "avatargone@example.com")
        user_id = _me(client, headers)["id"]
        _put(client, headers, PNG)
        client.delete("/api/user/me", headers=headers)

    remaining = (
        await session.execute(select(UserAvatar).where(UserAvatar.user_id == user_id))
    ).all()
    assert remaining == []
