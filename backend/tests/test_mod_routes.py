from litestar.testing import TestClient


def _entry(client: TestClient, headers: dict, space_id: int | None = None, **extra: object) -> dict:
    suffix = f"?space_id={space_id}" if space_id is not None else ""
    response = client.post(
        f"/api/backlog/entries{suffix}",
        headers=headers,
        json={
            "title": "Deep Rock Galactic",
            "genre": ["Action"],
            "platform": ["PC"],
            "status": "Not Started",
            "owned": True,
            "interest": 8,
            "steam_app_id": 548430,
            **extra,
        },
    )
    assert response.status_code == 201
    return response.json()


def _mods_url(entry_id: int, space_id: int | None = None) -> str:
    suffix = f"?space_id={space_id}" if space_id is not None else ""
    return f"/api/backlog/entries/{entry_id}/mods{suffix}"


def _make_space(client: TestClient, owner: dict, guest: dict, guest_name: str) -> int:
    invite = client.post("/api/space/invitations", headers=owner, json={"username": guest_name})
    assert invite.status_code == 201
    accept = client.post("/api/space/invitations/accept", headers=guest)
    assert accept.status_code == 200
    return accept.json()["space_id"]


async def test_mod_routes_require_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        statuses = [
            client.get("/api/backlog/entries/1/mods").status_code,
            client.post("/api/backlog/entries/1/mods", json={"name": "x"}).status_code,
            client.put("/api/backlog/entries/1/mods/1", json={"name": "x"}).status_code,
            client.delete("/api/backlog/entries/1/mods/1").status_code,
        ]

    assert statuses == [401] * 4


async def test_mods_can_be_added_listed_edited_and_removed(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "modowner@example.com")
        entry = _entry(client, headers)

        created = client.post(
            _mods_url(entry["id"]),
            headers=headers,
            json={"name": "Better Co-op", "url": "https://www.nexusmods.com/mod/1"},
        )
        no_link = client.post(_mods_url(entry["id"]), headers=headers, json={"name": "Tweaks"})
        listed = client.get(_mods_url(entry["id"]), headers=headers).json()
        mod_id = created.json()["id"]
        edited = client.put(
            f"/api/backlog/entries/{entry['id']}/mods/{mod_id}",
            headers=headers,
            json={"name": "Better Co-op 2", "url": None},
        )
        removed = client.delete(
            f"/api/backlog/entries/{entry['id']}/mods/{no_link.json()['id']}", headers=headers
        )
        after = client.get(_mods_url(entry["id"]), headers=headers).json()

    assert created.status_code == 201
    assert created.json()["url"] == "https://www.nexusmods.com/mod/1"
    assert no_link.status_code == 201
    assert no_link.json()["url"] is None
    assert [m["name"] for m in listed] == ["Better Co-op", "Tweaks"]
    assert edited.status_code == 200
    assert edited.json()["name"] == "Better Co-op 2"
    assert edited.json()["url"] is None
    assert removed.status_code == 204
    assert [m["name"] for m in after] == ["Better Co-op 2"]


async def test_a_mod_update_leaves_omitted_fields_alone(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "modpartial@example.com")
        entry = _entry(client, headers)
        mod = client.post(
            _mods_url(entry["id"]),
            headers=headers,
            json={"name": "Co-op", "url": "https://example.com/m"},
        ).json()

        updated = client.put(
            f"/api/backlog/entries/{entry['id']}/mods/{mod['id']}",
            headers=headers,
            json={"name": "Co-op v2"},
        )

    assert updated.json()["url"] == "https://example.com/m"


async def test_mods_reject_bad_names_and_links(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "modvalid@example.com")
        entry = _entry(client, headers)
        url = _mods_url(entry["id"])

        statuses = [
            client.post(url, headers=headers, json={"name": "   "}).status_code,
            client.post(url, headers=headers, json={"name": "x" * 121}).status_code,
            client.post(
                url, headers=headers, json={"name": "m", "url": "javascript:alert(1)"}
            ).status_code,
            client.post(
                url, headers=headers, json={"name": "m", "url": "ftp://example.com/m"}
            ).status_code,
            client.post(
                url, headers=headers, json={"name": "m", "url": "https://" + "a" * 2100}
            ).status_code,
        ]

    assert statuses == [400] * 5


async def test_an_entry_holds_at_most_one_hundred_mods(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "modlimit@example.com")
        entry = _entry(client, headers)
        for index in range(100):
            assert (
                client.post(
                    _mods_url(entry["id"]), headers=headers, json={"name": f"Mod {index}"}
                ).status_code
                == 201
            )

        one_more = client.post(_mods_url(entry["id"]), headers=headers, json={"name": "Extra"})

    assert one_more.status_code == 400


async def test_mods_of_another_users_entry_are_not_reachable(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "modprivateowner@example.com")
        other = await create_and_login(client, "modprivateother@example.com")
        entry = _entry(client, owner)
        mod = client.post(_mods_url(entry["id"]), headers=owner, json={"name": "Mine"}).json()

        statuses = [
            client.get(_mods_url(entry["id"]), headers=other).status_code,
            client.post(_mods_url(entry["id"]), headers=other, json={"name": "x"}).status_code,
            client.put(
                f"/api/backlog/entries/{entry['id']}/mods/{mod['id']}",
                headers=other,
                json={"name": "x"},
            ).status_code,
            client.delete(
                f"/api/backlog/entries/{entry['id']}/mods/{mod['id']}", headers=other
            ).status_code,
        ]

    assert statuses == [404] * 4


async def test_a_mod_is_only_reachable_through_its_own_entry(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "modwrongentry@example.com")
        first = _entry(client, headers)
        second = _entry(client, headers, title="Celeste", steam_app_id=504230)
        mod = client.post(_mods_url(first["id"]), headers=headers, json={"name": "Mine"}).json()

        update = client.put(
            f"/api/backlog/entries/{second['id']}/mods/{mod['id']}",
            headers=headers,
            json={"name": "x"},
        )
        delete = client.delete(
            f"/api/backlog/entries/{second['id']}/mods/{mod['id']}", headers=headers
        )

    assert (update.status_code, delete.status_code) == (404, 404)


async def test_both_members_share_the_mods_of_a_space_entry(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "modspaceowner@example.com")
        guest = await create_and_login(client, "modspaceguest@example.com")
        outsider = await create_and_login(client, "modspaceoutsider@example.com")
        space_id = _make_space(client, owner, guest, "modspaceguest")
        entry = _entry(client, owner, space_id)

        client.post(_mods_url(entry["id"], space_id), headers=owner, json={"name": "From owner"})
        client.post(_mods_url(entry["id"], space_id), headers=guest, json={"name": "From guest"})
        seen_by_owner = client.get(_mods_url(entry["id"], space_id), headers=owner).json()
        seen_by_guest = client.get(_mods_url(entry["id"], space_id), headers=guest).json()
        outsider_status = client.get(_mods_url(entry["id"], space_id), headers=outsider).status_code
        personal_scope = client.get(_mods_url(entry["id"]), headers=owner).status_code

    assert [m["name"] for m in seen_by_owner] == ["From owner", "From guest"]
    assert seen_by_guest == seen_by_owner
    assert outsider_status == 404
    assert personal_scope == 404


async def test_deleting_an_entry_deletes_its_mods(postgres_url: str, create_and_login) -> None:
    from sqlalchemy import func, select

    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.db import async_session
    from backlog_manager_backend.models.entry_mod import EntryMod

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "moddelete@example.com")
        entry = _entry(client, headers)
        client.post(_mods_url(entry["id"]), headers=headers, json={"name": "Mine"})

        client.delete(f"/api/backlog/entries/{entry['id']}", headers=headers)

        async with async_session() as session:
            rows = await session.scalar(select(func.count()).select_from(EntryMod))

    assert rows == 0


async def test_a_backup_restores_the_mods(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "modbackup@example.com")
        entry = _entry(client, headers)
        client.post(
            _mods_url(entry["id"]),
            headers=headers,
            json={"name": "Better Co-op", "url": "https://example.com/m"},
        )
        backup = client.post("/api/backups", headers=headers).json()
        client.delete(f"/api/backlog/entries/{entry['id']}", headers=headers)

        restored = client.post(f"/api/backups/{backup['id']}/restore", headers=headers)
        entries = client.get("/api/backlog/entries", headers=headers).json()
        mods = client.get(_mods_url(entries[0]["id"]), headers=headers).json()

    assert restored.status_code == 200
    assert [(m["name"], m["url"]) for m in mods] == [("Better Co-op", "https://example.com/m")]
