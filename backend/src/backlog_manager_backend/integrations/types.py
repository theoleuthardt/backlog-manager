import msgspec


class HltbResultData(msgspec.Struct, rename="camel"):
    """Field names mirror the HowLongToBeat API's camelCase JSON response
    (id, hltbId, title, imageUrl, ...) via msgspec's rename="camel"."""

    id: int
    hltb_id: int
    title: str
    image_url: str
    main_story: float
    main_story_with_extras: float
    completionist: float
    last_updated_at: str
    steam_app_id: int | None = None
    gog_app_id: int | None = None


class IGDBTokenResponse(msgspec.Struct):
    access_token: str
    expires_in: int
    token_type: str


class IGDBSearchResult(msgspec.Struct):
    id: int
    alternative_name: str | None = None
    game: int | None = None
    name: str | None = None
    published_at: int | None = None


class IGDBGameData(msgspec.Struct):
    id: int
    age_ratings: list[int] | None = None
    aggregated_rating: float | None = None
    aggregated_rating_count: int | None = None
    alternative_names: list[int] | None = None
    artworks: list[int] | None = None
    bundles: list[int] | None = None
    cover: int | None = None
    created_at: int | None = None
    dlcs: list[int] | None = None
    expansions: list[int] | None = None
    external_games: list[int] | None = None
    first_release_date: int | None = None
    franchises: list[int] | None = None
    game_engines: list[int] | None = None
    game_modes: list[int] | None = None
    genres: list[int] | None = None
    hypes: int | None = None
    involved_companies: list[int] | None = None
    keywords: list[int] | None = None
    name: str | None = None
    platforms: list[int] | None = None
    player_perspectives: list[int] | None = None
    rating: float | None = None
    rating_count: int | None = None
    release_dates: list[int] | None = None
    screenshots: list[int] | None = None
    similar_games: list[int] | None = None
    slug: str | None = None
    storyline: str | None = None
    summary: str | None = None
    tags: list[int] | None = None
    themes: list[int] | None = None
    total_rating: float | None = None
    total_rating_count: int | None = None
    updated_at: int | None = None
    url: str | None = None
    videos: list[int] | None = None
    websites: list[int] | None = None
    checksum: str | None = None
    language_supports: list[int] | None = None
    game_localizations: list[int] | None = None
    collections: list[int] | None = None
    game_type: int | None = None


class IGDBPlatform(msgspec.Struct):
    id: int
    abbreviation: str | None = None
    alternative_name: str | None = None
    category: int | None = None
    checksum: str | None = None
    created_at: int | None = None
    generation: int | None = None
    name: str | None = None
    platform_family: int | None = None
    platform_logo: int | None = None
    platform_type: int | None = None
    slug: str | None = None
    summary: str | None = None
    updated_at: int | None = None
    url: str | None = None
    versions: list[int] | None = None
    websites: list[int] | None = None


class IGDBGameTimeToBeat(msgspec.Struct):
    id: int
    checksum: str | None = None
    completely: int | None = None
    count: int | None = None
    created_at: int | None = None
    game_id: int | None = None
    hastily: int | None = None
    normally: int | None = None
    updated_at: int | None = None


class IGDBCover(msgspec.Struct):
    id: int
    alpha_channel: bool | None = None
    animated: bool | None = None
    checksum: str | None = None
    game: int | None = None
    game_localization: int | None = None
    height: int | None = None
    image_id: str | None = None
    url: str | None = None
    width: int | None = None


class IGDBGenre(msgspec.Struct):
    id: int
    checksum: str | None = None
    created_at: int | None = None
    name: str | None = None
    slug: str | None = None
    updated_at: int | None = None
    url: str | None = None


class EnrichedResult(msgspec.Struct):
    id: int
    hltb_id: int
    title: str
    image_url: str | None
    genres: list[str]
    platforms: list[str]
    main_story: float
    main_story_with_extras: float
    completionist: float
    steam_app_id: None = None


class SteamOwnedGame(msgspec.Struct):
    """Field names already match GetOwnedGames' JSON response verbatim -
    no rename= needed, unlike HltbResultData."""

    appid: int
    name: str
    playtime_forever: int


class SteamOwnedGamesResult(msgspec.Struct):
    """games is omitted entirely by the Steam API if the account's game
    list is private, hence the default empty list rather than a
    required field."""

    games: list[SteamOwnedGame] = []


class SteamGetOwnedGamesEnvelope(msgspec.Struct):
    response: SteamOwnedGamesResult
