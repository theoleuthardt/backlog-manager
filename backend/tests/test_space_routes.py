from litestar.testing import TestClient


def _entry_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "title": "Deep Rock Galactic",
        "genre": ["Action"],
        "platform": ["PC"],
        "status": "Not Started",
        "owned": True,
        "interest": 8,
        "steam_app_id": 548430,
    }
    payload.update(overrides)
    return payload


def _make_space(client: TestClient, owner_headers: dict, guest_headers: dict, guest_name: str) -> int:
    invite = client.post("/api/space/invitations", headers=owner_headers, json={"username": guest_name})
    assert invite.status_code == 201
    accept = client.post("/api/space/invitations/accept", headers=guest_headers)
    assert accept.status_code == 200
    return accept.json()["space_id"]


async def test_space_state_is_empty_for_user_without_space(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "spacelonely@example.com")
        response = client.get("/api/space", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"space_id": None, "my_status": None, "members": []}


async def test_invite_accept_flow(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spaceowner@example.com")
        guest = await create_and_login(client, "spaceguest@example.com")

        invite = client.post("/api/space/invitations", headers=owner, json={"username": "spaceguest"})
        owner_state = client.get("/api/space", headers=owner).json()
        guest_state = client.get("/api/space", headers=guest).json()
        accept = client.post("/api/space/invitations/accept", headers=guest)
        guest_after = client.get("/api/space", headers=guest).json()

    assert invite.status_code == 201
    assert owner_state["my_status"] == "active"
    assert {(m["username"], m["status"]) for m in owner_state["members"]} == {
        ("spaceowner", "active"),
        ("spaceguest", "invited"),
    }
    assert guest_state["my_status"] == "invited"
    assert accept.status_code == 200
    assert guest_after["my_status"] == "active"
    assert {m["status"] for m in guest_after["members"]} == {"active"}


async def test_invite_unknown_username_is_404(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "spaceinviter@example.com")
        response = client.post("/api/space/invitations", headers=headers, json={"username": "nobodyhere"})

    assert response.status_code == 404


async def test_cannot_invite_self(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "spaceselfinvite@example.com")
        response = client.post(
            "/api/space/invitations", headers=headers, json={"username": "spaceselfinvite"}
        )

    assert response.status_code == 400


async def test_space_holds_at_most_two_users(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacefullowner@example.com")
        guest = await create_and_login(client, "spacefullguest@example.com")
        await create_and_login(client, "spacefullthird@example.com")
        _make_space(client, owner, guest, "spacefullguest")

        response = client.post(
            "/api/space/invitations", headers=owner, json={"username": "spacefullthird"}
        )

    assert response.status_code == 409


async def test_cannot_invite_user_who_already_has_a_space(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacebusyowner@example.com")
        guest = await create_and_login(client, "spacebusyguest@example.com")
        other = await create_and_login(client, "spacebusyother@example.com")
        _make_space(client, owner, guest, "spacebusyguest")

        response = client.post(
            "/api/space/invitations", headers=other, json={"username": "spacebusyguest"}
        )

    assert response.status_code == 409


async def test_decline_removes_the_invitation(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacedeclowner@example.com")
        guest = await create_and_login(client, "spacedeclguest@example.com")
        client.post("/api/space/invitations", headers=owner, json={"username": "spacedeclguest"})

        decline = client.delete("/api/space/membership", headers=guest)
        guest_state = client.get("/api/space", headers=guest).json()
        owner_state = client.get("/api/space", headers=owner).json()

    assert decline.status_code == 204
    assert guest_state["space_id"] is None
    assert [m["username"] for m in owner_state["members"]] == ["spacedeclowner"]


async def test_accept_without_invitation_is_404(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "spacenoinvite@example.com")
        response = client.post("/api/space/invitations/accept", headers=headers)

    assert response.status_code == 404


async def test_both_members_share_entries_and_personal_list_stays_separate(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spaceshareowner@example.com")
        guest = await create_and_login(client, "spaceshareguest@example.com")
        space_id = _make_space(client, owner, guest, "spaceshareguest")

        created = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload()
        )
        guest_space = client.get(f"/api/backlog/entries?space_id={space_id}", headers=guest).json()
        owner_personal = client.get("/api/backlog/entries", headers=owner).json()
        guest_personal = client.get("/api/backlog/entries", headers=guest).json()

    assert created.status_code == 201
    assert [e["title"] for e in guest_space] == ["Deep Rock Galactic"]
    assert owner_personal == []
    assert guest_personal == []


async def test_space_entries_require_steam_app_id(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacesteamowner@example.com")
        guest = await create_and_login(client, "spacesteamguest@example.com")
        space_id = _make_space(client, owner, guest, "spacesteamguest")

        response = client.post(
            f"/api/backlog/entries?space_id={space_id}",
            headers=owner,
            json=_entry_payload(steam_app_id=None),
        )

    assert response.status_code == 400


async def test_same_steam_game_cannot_be_added_twice_to_a_space(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacedupowner@example.com")
        guest = await create_and_login(client, "spacedupguest@example.com")
        space_id = _make_space(client, owner, guest, "spacedupguest")
        client.post(f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload())

        second = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=guest, json=_entry_payload()
        )

    assert second.status_code == 409


async def test_personal_and_space_entry_for_same_game_can_coexist(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacecoexowner@example.com")
        guest = await create_and_login(client, "spacecoexguest@example.com")
        space_id = _make_space(client, owner, guest, "spacecoexguest")

        personal = client.post("/api/backlog/entries", headers=owner, json=_entry_payload())
        shared = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload()
        )

    assert personal.status_code == 201
    assert shared.status_code == 201


async def test_non_member_cannot_access_a_space(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spaceintownr@example.com")
        guest = await create_and_login(client, "spaceintguest@example.com")
        intruder = await create_and_login(client, "spaceintruder@example.com")
        space_id = _make_space(client, owner, guest, "spaceintguest")
        entry = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload()
        ).json()

        listing = client.get(f"/api/backlog/entries?space_id={space_id}", headers=intruder)
        create = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=intruder, json=_entry_payload()
        )
        personal_access = client.get(f"/api/backlog/entries/{entry['id']}", headers=intruder)
        scoped_access = client.get(
            f"/api/backlog/entries/{entry['id']}?space_id={space_id}", headers=intruder
        )

    assert listing.status_code == 404
    assert create.status_code == 404
    assert personal_access.status_code == 404
    assert scoped_access.status_code == 404


async def test_invited_but_not_accepted_user_cannot_access_space(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacependowner@example.com")
        guest = await create_and_login(client, "spacependguest@example.com")
        client.post("/api/space/invitations", headers=owner, json={"username": "spacependguest"})
        space_id = client.get("/api/space", headers=owner).json()["space_id"]

        response = client.get(f"/api/backlog/entries?space_id={space_id}", headers=guest)

    assert response.status_code == 404


async def test_owner_entry_is_not_reachable_through_personal_endpoints(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacepersowner@example.com")
        guest = await create_and_login(client, "spacepersguest@example.com")
        space_id = _make_space(client, owner, guest, "spacepersguest")
        entry = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload()
        ).json()

        via_personal = client.get(f"/api/backlog/entries/{entry['id']}", headers=owner)
        via_space_by_guest = client.get(
            f"/api/backlog/entries/{entry['id']}?space_id={space_id}", headers=guest
        )

    assert via_personal.status_code == 404
    assert via_space_by_guest.status_code == 200


async def test_status_and_shared_fields_are_visible_to_both_members(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacestatowner@example.com")
        guest = await create_and_login(client, "spacestatguest@example.com")
        space_id = _make_space(client, owner, guest, "spacestatguest")
        entry = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload()
        ).json()

        update = client.put(
            f"/api/backlog/entries/{entry['id']}?space_id={space_id}",
            headers=guest,
            json={"status": "In Progress", "note": "weekend run"},
        )
        owner_view = client.get(
            f"/api/backlog/entries/{entry['id']}?space_id={space_id}", headers=owner
        ).json()

    assert update.status_code == 200
    assert owner_view["status"] == "In Progress"
    assert owner_view["note"] == "weekend run"


async def test_rating_and_playtime_are_per_user_and_partner_playtime_is_visible(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacerateowner@example.com")
        guest = await create_and_login(client, "spacerateguest@example.com")
        space_id = _make_space(client, owner, guest, "spacerateguest")
        entry = client.post(
            f"/api/backlog/entries?space_id={space_id}",
            headers=owner,
            json=_entry_payload(review_stars=9, review="Rock and Stone", playtime=12.5),
        ).json()
        url = f"/api/backlog/entries/{entry['id']}?space_id={space_id}"

        guest_before = client.get(url, headers=guest).json()
        guest_update = client.put(url, headers=guest, json={"review_stars": 4, "playtime": 3})
        owner_view = client.get(url, headers=owner).json()
        guest_view = client.get(url, headers=guest).json()

    assert entry["review_stars"] == 9
    assert entry["playtime"] == "12.50"
    assert guest_before["review_stars"] is None
    assert guest_before["review"] is None
    assert guest_before["playtime"] is None
    assert guest_before["partner_playtime"] == "12.50"
    assert guest_update.status_code == 200
    assert owner_view["review_stars"] == 9
    assert owner_view["review"] == "Rock and Stone"
    assert owner_view["playtime"] == "12.50"
    assert owner_view["partner_playtime"] == "3.00"
    assert guest_view["review_stars"] == 4
    assert guest_view["playtime"] == "3.00"
    assert guest_view["partner_playtime"] == "12.50"


async def test_personal_entries_have_no_partner_playtime(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "spacepartnerless@example.com")
        entry = client.post(
            "/api/backlog/entries", headers=headers, json=_entry_payload(playtime=2)
        ).json()

    assert entry["playtime"] == "2.00"
    assert entry["partner_playtime"] is None


async def test_categories_and_statuses_are_shared_within_the_space(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacecatowner@example.com")
        guest = await create_and_login(client, "spacecatguest@example.com")
        space_id = _make_space(client, owner, guest, "spacecatguest")
        entry = client.post(
            f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload()
        ).json()

        category = client.post(
            f"/api/backlog/categories?space_id={space_id}",
            headers=owner,
            json={"category_name": "Co-Op Nights", "color": "#ff0000"},
        ).json()
        status = client.post(
            f"/api/backlog/statuses?space_id={space_id}", headers=owner, json={"name": "Next Session"}
        )
        assign = client.post(
            f"/api/backlog/entries/{entry['id']}/categories/{category['id']}?space_id={space_id}",
            headers=guest,
        )
        guest_categories = client.get(f"/api/backlog/categories?space_id={space_id}", headers=guest).json()
        guest_statuses = client.get(f"/api/backlog/statuses?space_id={space_id}", headers=guest).json()
        in_category = client.get(
            f"/api/backlog/categories/{category['id']}/entries?space_id={space_id}", headers=owner
        ).json()
        owner_personal_categories = client.get("/api/backlog/categories", headers=owner).json()
        owner_personal_statuses = client.get("/api/backlog/statuses", headers=owner).json()

    assert status.status_code == 201
    assert assign.status_code == 201
    assert [c["name"] for c in guest_categories] == ["Co-Op Nights"]
    assert [s["name"] for s in guest_statuses] == ["Next Session"]
    assert [e["title"] for e in in_category] == ["Deep Rock Galactic"]
    assert owner_personal_categories == []
    assert owner_personal_statuses == []


async def test_space_category_is_not_usable_from_personal_scope(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacexscopeowner@example.com")
        guest = await create_and_login(client, "spacexscopeguest@example.com")
        space_id = _make_space(client, owner, guest, "spacexscopeguest")
        category = client.post(
            f"/api/backlog/categories?space_id={space_id}",
            headers=owner,
            json={"category_name": "Co-Op Nights"},
        ).json()

        response = client.delete(f"/api/backlog/categories/{category['id']}", headers=owner)

    assert response.status_code == 404


async def test_leaving_revokes_access_and_remaining_member_keeps_entries(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spaceleaveowner@example.com")
        guest = await create_and_login(client, "spaceleaveguest@example.com")
        space_id = _make_space(client, owner, guest, "spaceleaveguest")
        client.post(f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload())

        leave = client.delete("/api/space/membership", headers=guest)
        guest_access = client.get(f"/api/backlog/entries?space_id={space_id}", headers=guest)
        owner_entries = client.get(f"/api/backlog/entries?space_id={space_id}", headers=owner).json()

    assert leave.status_code == 204
    assert guest_access.status_code == 404
    assert [e["title"] for e in owner_entries] == ["Deep Rock Galactic"]


async def test_space_is_deleted_when_last_member_leaves(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacegoneowner@example.com")
        guest = await create_and_login(client, "spacegoneguest@example.com")
        space_id = _make_space(client, owner, guest, "spacegoneguest")
        client.post(f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload())

        client.delete("/api/space/membership", headers=guest)
        client.delete("/api/space/membership", headers=owner)
        state = client.get("/api/space", headers=owner).json()
        entries = client.get(f"/api/backlog/entries?space_id={space_id}", headers=owner)

    assert state["space_id"] is None
    assert entries.status_code == 404


async def test_duplicate_check_is_scoped_to_the_space(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        owner = await create_and_login(client, "spacedupchkowner@example.com")
        guest = await create_and_login(client, "spacedupchkguest@example.com")
        space_id = _make_space(client, owner, guest, "spacedupchkguest")
        client.post(f"/api/backlog/entries?space_id={space_id}", headers=owner, json=_entry_payload())

        in_space = client.get(
            f"/api/backlog/entries/duplicates?title=Deep Rock Galactic&space_id={space_id}",
            headers=guest,
        ).json()
        personal = client.get(
            "/api/backlog/entries/duplicates?title=Deep Rock Galactic", headers=guest
        ).json()

    assert [e["title"] for e in in_space] == ["Deep Rock Galactic"]
    assert personal == []
