"""Seeds a running backend for the mobile tour of the app (the "Mobile
Tour" workflow, #576) through its own HTTP API: the initial admin (from
INITIAL_ADMIN_EMAIL / INITIAL_ADMIN_PASSWORD, created by the backend at
startup) gets a backlog of games in every status with Steam covers,
categories, notes, reviews and mods, a second user joins them in a shared
space with games of its own, and both get a backup. Standard library only,
so it runs with the backend's interpreter and nothing else.

Usage: python scripts/seed_mobile_tour.py [base_url]
"""

import json
import os
import sys
import urllib.error
import urllib.request

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
ADMIN_EMAIL = os.environ["INITIAL_ADMIN_EMAIL"]
ADMIN_PASSWORD = os.environ["INITIAL_ADMIN_PASSWORD"]
PARTNER_EMAIL = "alex@example.com"
PARTNER_USERNAME = "alex"

GAMES = [
    ("Hades", 1145360, "Completed", ["Roguelike", "Action"], 22, 48, 95),
    ("Celeste", 504230, "Completed", ["Platformer"], 8, 13, 40),
    ("Hollow Knight", 367520, "In Progress", ["Metroidvania", "Action"], 27, 41, 63),
    ("Stardew Valley", 413150, "In Progress", ["Simulation", "RPG"], 53, 95, 160),
    ("Portal 2", 620, "Completed", ["Puzzle"], 8, 13, 22),
    ("The Witcher 3: Wild Hunt", 292030, "On Hold", ["RPG", "Open World"], 51, 103, 173),
    ("Cyberpunk 2077", 1091500, "In Progress", ["RPG", "Shooter"], 25, 60, 104),
    ("Disco Elysium", 632470, "Not Started", ["RPG"], 22, 33, 48),
    ("Outer Wilds", 753640, "Not Started", ["Adventure", "Puzzle"], 17, 22, 27),
    ("Slay the Spire", 646570, "In Progress", ["Roguelike", "Card Game"], 18, 36, 100),
    ("Dead Cells", 588650, "Dropped", ["Roguelike", "Metroidvania"], 13, 28, 99),
    ("Terraria", 105600, "On Hold", ["Sandbox"], 52, 102, 196),
    ("Baldur's Gate 3", 1086940, "Not Started", ["RPG"], 75, 117, 160),
    ("Elden Ring", 1245620, "Dropped", ["Action RPG"], 59, 100, 133),
    ("Inscryption", 1092790, "Completed", ["Card Game", "Horror"], 12, 17, 22),
    ("Return of the Obra Dinn", 653530, "Not Started", ["Puzzle"], 8, 10, 11),
    ("Balatro", 2379780, "In Progress", ["Card Game", "Roguelike"], 10, 32, 100),
    ("Subnautica", 264710, "Not Owned", ["Survival"], 31, 45, 56),
    ("Sea of Stars", 1244090, "Not Owned", ["RPG"], 29, 38, 50),
    ("Tunic", 553420, "Not Started", ["Adventure"], 12, 18, 22),
    ("Pizza Tower", 2231450, "Completed", ["Platformer"], 6, 9, 20),
    ("A Short Hike", 1055540, "Completed", ["Adventure"], 2, 3, 4),
    ("Death's Door", 894020, "Not Started", ["Action"], 10, 13, 17),
    ("Hi-Fi Rush", 1817230, "On Hold", ["Action", "Rhythm"], 11, 17, 30),
    ("Vampire Survivors", 1794680, "In Progress", ["Roguelike"], 15, 40, 100),
    ("Cult of the Lamb", 1313140, "Not Started", ["Roguelike", "Simulation"], 16, 24, 40),
    ("Gris", 683320, "Completed", ["Platformer"], 4, 4, 5),
    ("Ori and the Will of the Wisps", 1057090, "Not Started", ["Metroidvania"], 11, 15, 19),
]

SPACE_GAMES = [
    ("It Takes Two", 1426210, "In Progress", ["Co-op", "Adventure"], 13, 16, 20),
    ("Risk of Rain 2", 632360, "In Progress", ["Roguelike", "Co-op"], 15, 40, 90),
    ("Deep Rock Galactic", 548430, "On Hold", ["Co-op", "Shooter"], 50, 100, 200),
    ("Overcooked! 2", 728880, "Not Started", ["Co-op", "Party"], 9, 14, 30),
    ("Valheim", 892970, "Not Started", ["Survival", "Co-op"], 60, 90, 130),
    ("Portal 2", 620, "Completed", ["Puzzle", "Co-op"], 8, 13, 22),
]

CATEGORIES = [
    ("Short games", "#22c55e", ["A Short Hike", "Gris", "Pizza Tower", "Portal 2", "Celeste"]),
    ("Big adventures", "#f59e0b", ["The Witcher 3: Wild Hunt", "Baldur's Gate 3", "Elden Ring"]),
    ("Card games", "#a855f7", ["Slay the Spire", "Inscryption", "Balatro"]),
]


def cover(app_id: int) -> str:
    return f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}/library_600x900.jpg"


def call(method: str, path: str, token: str | None = None, body: object = None) -> object:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(BASE_URL + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} failed with {error.code}: {error.read().decode()}")
    return json.loads(raw) if raw else None


def login(email: str, password: str) -> str:
    result = call("POST", "/api/auth/login", body={"email": email, "password": password})
    return result["access_token"]


def entry(game: tuple, *, note: str | None = None, review: str | None = None) -> dict:
    title, app_id, status, genre, main, extra, complete = game
    done = status == "Completed"
    return {
        "title": title,
        "genre": genre,
        "platform": ["PC", "Steam Deck"] if app_id % 2 else ["PC"],
        "status": status,
        "owned": status != "Not Owned",
        "interest": (app_id % 10) + 1,
        "image_link": cover(app_id),
        "steam_app_id": app_id,
        "main_time": main,
        "main_plus_extra_time": extra,
        "completion_time": complete,
        "playtime": main * 1.2 if done else (main / 3 if status == "In Progress" else None),
        "review_stars": 4.5 if done else None,
        "review": review if done else None,
        "note": note,
        "description": f"{title} is one of the games of the mobile tour.",
    }


def main() -> None:
    admin = login(ADMIN_EMAIL, ADMIN_PASSWORD)
    call("PUT", "/api/user/me", admin, {"setup_completed": True, "steam_id": "76561197960287930"})
    call(
        "POST",
        "/api/admin/users",
        admin,
        {"username": PARTNER_USERNAME, "email": PARTNER_EMAIL, "password": ADMIN_PASSWORD},
    )
    partner = login(PARTNER_EMAIL, ADMIN_PASSWORD)
    call("PUT", "/api/user/me", partner, {"setup_completed": True})

    ids = {}
    for index, game in enumerate(GAMES):
        created = call(
            "POST",
            "/api/backlog/entries",
            admin,
            entry(
                game,
                note="Play on the handheld." if index % 4 == 0 else None,
                review="Loved every minute of it." if index % 3 == 0 else None,
            ),
        )
        ids[game[0]] = created["id"]

    for name, color, titles in CATEGORIES:
        category = call(
            "POST",
            "/api/backlog/categories",
            admin,
            {"category_name": name, "color": color, "description": name},
        )
        for title in titles:
            call("POST", f"/api/backlog/entries/{ids[title]}/categories/{category['id']}", admin)

    for name, url in [
        ("HD texture pack", "https://www.nexusmods.com/witcher3"),
        ("Better minimap", None),
    ]:
        call(
            "POST",
            f"/api/backlog/entries/{ids['The Witcher 3: Wild Hunt']}/mods",
            admin,
            {"name": name, "url": url} if url else {"name": name},
        )

    call("POST", "/api/space/invitations", admin, {"username": PARTNER_USERNAME})
    space = call("POST", "/api/space/invitations/accept", partner)
    space_id = space["space_id"]
    for index, game in enumerate(SPACE_GAMES):
        call(
            "POST",
            f"/api/backlog/entries?space_id={space_id}",
            admin if index % 2 == 0 else partner,
            entry(game),
        )
    call(
        "POST",
        f"/api/backlog/categories?space_id={space_id}",
        admin,
        {"category_name": "Weekend", "color": "#38bdf8", "description": "Weekend"},
    )

    call("POST", "/api/backups", admin)
    call("POST", "/api/space/backups", admin)
    print(f"Seeded {len(GAMES)} games, {len(SPACE_GAMES)} shared games, space {space_id}.")


if __name__ == "__main__":
    main()
