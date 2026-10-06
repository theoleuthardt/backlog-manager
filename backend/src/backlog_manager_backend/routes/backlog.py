import msgspec
from litestar import Router, delete, get, post, put
from litestar.di import NamedDependency, Provide
from litestar.exceptions import ClientException, NotFoundException, ValidationException
from litestar.params import FromPath, FromQuery
from litestar.status_codes import HTTP_409_CONFLICT
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.errors import ConflictError, NotFoundError
from backlog_manager_backend.repositories import (
    backlog_entry_repo,
    category_backlog_entry_repo,
    category_repo,
    custom_status_repo,
    space_entry_member_repo,
    space_repo,
)
from backlog_manager_backend.schemas.backlog_entry import (
    BacklogEntry,
    BacklogEntryResponse,
    CategoryBacklogAssociationParams,
    CreateBacklogEntryParams,
    CreateBacklogEntryRequest,
    GetEntriesByStatusParams,
    UpdateBacklogEntryParams,
    UpdateBacklogEntryRequest,
)
from backlog_manager_backend.schemas.category import (
    Category,
    CategoryResponse,
    CreateCategoryParams,
    CreateCategoryRequest,
    UpdateCategoryParams,
    UpdateCategoryRequest,
)
from backlog_manager_backend.schemas.custom_status import (
    CreateCustomStatusParams,
    CreateCustomStatusRequest,
    CustomStatus,
    CustomStatusResponse,
    UpdateCustomStatusParams,
    UpdateCustomStatusRequest,
)
from backlog_manager_backend.schemas.user import User
from backlog_manager_backend.services import backup_service

_ENTRY_NOT_FOUND = "Backlog entry not found"
_CATEGORY_NOT_FOUND = "Category not found"
_STATUS_NOT_FOUND = "Custom status not found"
_SPACE_NOT_FOUND = "Space not found"
DEFAULT_STATUSES = ("Not Started", "In Progress", "Completed", "On Hold", "Dropped")
_STATUS_NAME_MAX_LENGTH = 20


class _ConflictException(ClientException):
    """Documents the 409 a duplicate custom-status name or a duplicate Steam
    game in one scope raises, distinct from ClientException's default 400 so
    it shows up in the OpenAPI response union via the handlers' `raises=`
    declarations."""

    status_code = HTTP_409_CONFLICT


async def _require_space_access(session: AsyncSession, user: User, space_id: int | None) -> None:
    """Every scoped handler goes through this first: `space_id` selects
    the shared space instead of the caller's personal backlog, which is
    only allowed for an active member. Anyone else gets the same 404 as
    for a space that doesn't exist, so a space's existence isn't
    revealed."""
    if space_id is None:
        return
    membership = await space_repo.get_membership(session, user.id)
    if membership is None or membership.space_id != space_id or membership.status != "active":
        raise NotFoundException(_SPACE_NOT_FOUND)


async def _get_scoped_entry(
    session: AsyncSession, entry_id: int, user: User, space_id: int | None
) -> BacklogEntry:
    """Raises the same response as a real 404 when the entry is outside
    the requested scope (another user's, or a personal entry requested
    through a space and vice versa) - existence of another user's
    resource isn't revealed by a distinct 403."""
    await _require_space_access(session, user, space_id)
    try:
        entry = await backlog_entry_repo.get_backlog_entry_by_id(session, entry_id)
    except NotFoundError as error:
        raise NotFoundException(_ENTRY_NOT_FOUND) from error
    if space_id is not None:
        in_scope = entry.space_id == space_id
    else:
        in_scope = entry.space_id is None and entry.user_id == user.id
    if not in_scope:
        raise NotFoundException(_ENTRY_NOT_FOUND)
    return entry


async def _get_scoped_category(
    session: AsyncSession, category_id: int, user: User, space_id: int | None
) -> Category:
    await _require_space_access(session, user, space_id)
    categories = (
        await category_repo.get_categories_by_space(session, space_id)
        if space_id is not None
        else await category_repo.get_categories_by_user(session, user.id)
    )
    category = next((c for c in categories if c.category_id == category_id), None)
    if category is None:
        raise NotFoundException(_CATEGORY_NOT_FOUND)
    return category


async def _present(
    session: AsyncSession, entries: list[BacklogEntry], user: User
) -> list[BacklogEntryResponse]:
    shown = await space_entry_member_repo.apply_member_data(session, entries, user.id)
    return [BacklogEntryResponse.from_entry(entry) for entry in shown]


def _join_tags(field_name: str, values: list[str]) -> str:
    """The DB stores genre/platform as one ", "-joined column (unchanged
    from the original schema), so a value containing that delimiter
    would silently split back into multiple values on the next read -
    rejected here rather than persisted lossily."""
    for value in values:
        if "," in value:
            raise ValidationException(f"{field_name} entries must not contain a comma: {value!r}")
    return ", ".join(values)


@post(
    "/api/backlog/entries",
    status_code=201,
    raises=[NotFoundException, ValidationException, _ConflictException],
)
async def create_entry(
    data: CreateBacklogEntryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> BacklogEntryResponse:
    """With `space_id` the entry is created in that shared space, which
    only tracks Steam games (steam_app_id is required). Its playtime,
    rating and review are stored as the creator's own member data rather
    than on the shared entry row."""
    await _require_space_access(db_session, current_user, space_id)
    if space_id is not None and data.steam_app_id is None:
        raise ValidationException("Entries in a shared space must be Steam games")
    review_stars = round(data.review_stars) if data.review_stars is not None else None
    try:
        entry = await backlog_entry_repo.create_backlog_entry(
            db_session,
            CreateBacklogEntryParams(
                user_id=current_user.id,
                space_id=space_id,
                title=data.title,
                genre=_join_tags("genre", data.genre),
                platform=_join_tags("platform", data.platform),
                status=data.status,
                owned=data.owned,
                interest=data.interest,
                release_date=data.release_date,
                image_link=data.image_link,
                description=data.description,
                trailer_link=data.trailer_link,
                publisher=data.publisher,
                main_time=data.main_time,
                main_plus_extra_time=data.main_plus_extra_time,
                completion_time=data.completion_time,
                playtime=data.playtime if space_id is None else None,
                steam_app_id=data.steam_app_id,
                review_stars=review_stars if space_id is None else None,
                review=data.review if space_id is None else None,
                note=data.note,
            ),
        )
    except ConflictError as error:
        raise _ConflictException("This game is already in that backlog") from error
    if space_id is not None and (
        data.playtime is not None or review_stars is not None or data.review is not None
    ):
        await space_entry_member_repo.upsert_member_data(
            db_session,
            entry.backlog_entry_id,
            current_user.id,
            playtime=data.playtime,
            review_stars=review_stars,
            review=data.review,
        )
    return (await _present(db_session, [entry], current_user))[0]


@get("/api/backlog/entries", raises=[NotFoundException])
async def list_entries(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    status: FromQuery[str | None] = None,
    space_id: FromQuery[int | None] = None,
) -> list[BacklogEntryResponse]:
    await _require_space_access(db_session, current_user, space_id)
    if space_id is not None:
        entries = await backlog_entry_repo.get_backlog_entries_by_space(db_session, space_id)
        if status is not None:
            entries = [entry for entry in entries if entry.status == status]
    elif status is not None:
        entries = await backlog_entry_repo.get_backlog_entries_by_status(
            db_session, GetEntriesByStatusParams(user_id=current_user.id, status=status)
        )
    else:
        entries = await backlog_entry_repo.get_backlog_entries_by_user(db_session, current_user.id)
    return await _present(db_session, entries, current_user)


@get("/api/backlog/entries/duplicates", raises=[NotFoundException, ValidationException])
async def get_entry_duplicates(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    title: FromQuery[str],
    steam_app_id: FromQuery[int | None] = None,
    space_id: FromQuery[int | None] = None,
) -> list[BacklogEntryResponse]:
    """Pre-create duplicate check for the creation tool: returns the
    entries of the requested scope (the caller's personal backlog, or
    the shared space) that already track this game, matched by title
    (case-insensitive) or steam app id, so the UI can ask whether to
    add it anyway."""
    await _require_space_access(db_session, current_user, space_id)
    title = title.strip()
    if not title:
        raise ValidationException("title must not be empty")
    entries = await backlog_entry_repo.get_backlog_entry_duplicates(
        db_session, current_user.id, title, steam_app_id, space_id
    )
    return await _present(db_session, entries, current_user)


@get("/api/backlog/entries/{entry_id:int}", raises=[NotFoundException])
async def get_entry(
    entry_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> BacklogEntryResponse:
    entry = await _get_scoped_entry(db_session, entry_id, current_user, space_id)
    return (await _present(db_session, [entry], current_user))[0]


@put(
    "/api/backlog/entries/{entry_id:int}",
    raises=[NotFoundException, ValidationException, _ConflictException],
)
async def update_entry(
    entry_id: FromPath[int],
    data: UpdateBacklogEntryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> BacklogEntryResponse:
    """In a shared space, playtime, review_stars and review are the
    caller's own member data and never touch the shared entry row."""
    await _get_scoped_entry(db_session, entry_id, current_user, space_id)
    if space_id is not None and data.steam_app_id is None:
        raise ValidationException("Entries in a shared space must stay linked to a Steam game")

    review_stars = data.review_stars
    if isinstance(review_stars, float):
        review_stars = round(review_stars)

    params = UpdateBacklogEntryParams(
        backlog_entry_id=entry_id,
        title=data.title,
        genre=_join_tags("genre", data.genre) if isinstance(data.genre, list) else data.genre,
        platform=(
            _join_tags("platform", data.platform)
            if isinstance(data.platform, list)
            else data.platform
        ),
        status=data.status,
        owned=data.owned,
        interest=data.interest,
        release_date=data.release_date,
        image_link=data.image_link,
        description=data.description,
        trailer_link=data.trailer_link,
        publisher=data.publisher,
        main_time=data.main_time,
        main_plus_extra_time=data.main_plus_extra_time,
        completion_time=data.completion_time,
        playtime=data.playtime if space_id is None else msgspec.UNSET,
        steam_app_id=data.steam_app_id,
        review_stars=review_stars if space_id is None else msgspec.UNSET,
        review=data.review if space_id is None else msgspec.UNSET,
        note=data.note,
    )
    try:
        entry = await backlog_entry_repo.update_backlog_entry(db_session, params)
    except ConflictError as error:
        raise _ConflictException("This game is already in that backlog") from error
    if space_id is not None:
        await space_entry_member_repo.upsert_member_data(
            db_session,
            entry_id,
            current_user.id,
            playtime=data.playtime,
            review_stars=review_stars,
            review=data.review,
        )
    return (await _present(db_session, [entry], current_user))[0]


@delete("/api/backlog/entries/{entry_id:int}", raises=[NotFoundException])
async def delete_entry(
    entry_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> None:
    await _get_scoped_entry(db_session, entry_id, current_user, space_id)
    await backlog_entry_repo.delete_backlog_entry(db_session, entry_id)


@delete("/api/backlog/entries", status_code=200, raises=[NotFoundException])
async def delete_all_entries(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> int:
    """Bulk variant of delete_entry - permanently deletes every backlog
    entry of the caller's personal backlog, or of the shared space when
    `space_id` is given and the caller is an active member (category
    associations cascade). Without `space_id` a space's entries are
    never touched. Returns the number of entries removed. A personal wipe
    takes a "pre-delete" backup first so it can be reverted from the
    backups list; shared space content is not part of backups."""
    await _require_space_access(db_session, current_user, space_id)
    if space_id is not None:
        return await backlog_entry_repo.delete_backlog_entries_by_space(db_session, space_id)
    await backup_service.create_backup(db_session, current_user.id, backup_service.PRE_DELETE)
    return await backlog_entry_repo.delete_backlog_entries_by_user(db_session, current_user.id)


@get("/api/backlog/entries/{entry_id:int}/categories", raises=[NotFoundException])
async def get_categories_for_entry(
    entry_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> list[CategoryResponse]:
    await _get_scoped_entry(db_session, entry_id, current_user, space_id)
    categories = await category_repo.get_categories_for_backlog_entry(db_session, entry_id)
    return [CategoryResponse.from_category(category) for category in categories]


@post(
    "/api/backlog/entries/{entry_id:int}/categories/{category_id:int}",
    status_code=201,
    raises=[NotFoundException],
)
async def add_category_to_entry(
    entry_id: FromPath[int],
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> None:
    await _get_scoped_entry(db_session, entry_id, current_user, space_id)
    await _get_scoped_category(db_session, category_id, current_user, space_id)
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        db_session,
        CategoryBacklogAssociationParams(category_id=category_id, backlog_entry_id=entry_id),
    )


@delete(
    "/api/backlog/entries/{entry_id:int}/categories/{category_id:int}",
    raises=[NotFoundException],
)
async def remove_category_from_entry(
    entry_id: FromPath[int],
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> None:
    await _get_scoped_entry(db_session, entry_id, current_user, space_id)
    await _get_scoped_category(db_session, category_id, current_user, space_id)
    await category_backlog_entry_repo.remove_backlog_entry_from_category(
        db_session,
        CategoryBacklogAssociationParams(category_id=category_id, backlog_entry_id=entry_id),
    )


@post("/api/backlog/categories", status_code=201, raises=[NotFoundException])
async def create_category(
    data: CreateCategoryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> CategoryResponse:
    await _require_space_access(db_session, current_user, space_id)
    category = await category_repo.create_category(
        db_session,
        CreateCategoryParams(
            user_id=current_user.id,
            space_id=space_id,
            category_name=data.category_name,
            color=data.color,
            description=data.description,
        ),
    )
    return CategoryResponse.from_category(category)


@get("/api/backlog/categories", raises=[NotFoundException])
async def list_categories(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> list[CategoryResponse]:
    await _require_space_access(db_session, current_user, space_id)
    categories = (
        await category_repo.get_categories_by_space(db_session, space_id)
        if space_id is not None
        else await category_repo.get_categories_by_user(db_session, current_user.id)
    )
    return [CategoryResponse.from_category(category) for category in categories]


@put("/api/backlog/categories/{category_id:int}", raises=[NotFoundException])
async def update_category(
    category_id: FromPath[int],
    data: UpdateCategoryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> CategoryResponse:
    await _get_scoped_category(db_session, category_id, current_user, space_id)
    category = await category_repo.update_category(
        db_session,
        UpdateCategoryParams(
            category_id=category_id,
            category_name=data.category_name,
            color=data.color,
            description=data.description,
        ),
    )
    return CategoryResponse.from_category(category)


@delete("/api/backlog/categories/{category_id:int}", raises=[NotFoundException])
async def delete_category(
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> None:
    await _get_scoped_category(db_session, category_id, current_user, space_id)
    await category_repo.delete_category(db_session, category_id)


@get("/api/backlog/categories/{category_id:int}/entries", raises=[NotFoundException])
async def get_entries_for_category(
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> list[BacklogEntryResponse]:
    await _get_scoped_category(db_session, category_id, current_user, space_id)
    entries = await backlog_entry_repo.get_backlog_entries_for_category(db_session, category_id)
    return await _present(db_session, entries, current_user)


def _validated_status_name(raw_name: str) -> str:
    name = raw_name.strip()
    if not name:
        raise ValidationException("Status name must not be empty")
    if len(name) > _STATUS_NAME_MAX_LENGTH:
        raise ValidationException(
            f"Status name must be at most {_STATUS_NAME_MAX_LENGTH} characters"
        )
    return name


async def _get_scoped_status(
    session: AsyncSession, status_id: int, user: User, space_id: int | None
) -> CustomStatus:
    await _require_space_access(session, user, space_id)
    try:
        status = await custom_status_repo.get_custom_status_by_id(session, status_id)
    except NotFoundError as error:
        raise NotFoundException(_STATUS_NOT_FOUND) from error
    if space_id is not None:
        in_scope = status.space_id == space_id
    else:
        in_scope = status.space_id is None and status.user_id == user.id
    if not in_scope:
        raise NotFoundException(_STATUS_NOT_FOUND)
    return status


@post(
    "/api/backlog/statuses",
    status_code=201,
    raises=[NotFoundException, ValidationException, _ConflictException],
)
async def create_custom_status(
    data: CreateCustomStatusRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> CustomStatusResponse:
    await _require_space_access(db_session, current_user, space_id)
    name = _validated_status_name(data.name)
    if name in DEFAULT_STATUSES:
        raise ValidationException(f"{name!r} is already a default status")
    try:
        status = await custom_status_repo.create_custom_status(
            db_session,
            CreateCustomStatusParams(user_id=current_user.id, space_id=space_id, name=name),
        )
    except ConflictError as error:
        raise _ConflictException(f"A status named {name!r} already exists") from error
    return CustomStatusResponse.from_status(status)


@get("/api/backlog/statuses", raises=[NotFoundException])
async def list_custom_statuses(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> list[CustomStatusResponse]:
    await _require_space_access(db_session, current_user, space_id)
    statuses = (
        await custom_status_repo.get_custom_statuses_by_space(db_session, space_id)
        if space_id is not None
        else await custom_status_repo.get_custom_statuses_by_user(db_session, current_user.id)
    )
    return [CustomStatusResponse.from_status(status) for status in statuses]


@put(
    "/api/backlog/statuses/{status_id:int}",
    raises=[NotFoundException, ValidationException, _ConflictException],
)
async def update_custom_status(
    status_id: FromPath[int],
    data: UpdateCustomStatusRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> CustomStatusResponse:
    await _get_scoped_status(db_session, status_id, current_user, space_id)
    name = _validated_status_name(data.name)
    if name in DEFAULT_STATUSES:
        raise ValidationException(f"{name!r} is already a default status")
    try:
        status = await custom_status_repo.update_custom_status(
            db_session, UpdateCustomStatusParams(status_id=status_id, name=name)
        )
    except ConflictError as error:
        raise _ConflictException(f"A status named {name!r} already exists") from error
    return CustomStatusResponse.from_status(status)


@delete("/api/backlog/statuses/{status_id:int}", raises=[NotFoundException])
async def delete_custom_status(
    status_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    space_id: FromQuery[int | None] = None,
) -> None:
    await _get_scoped_status(db_session, status_id, current_user, space_id)
    await custom_status_repo.delete_custom_status(db_session, status_id)


backlog_router = Router(
    path="",
    route_handlers=[
        create_entry,
        list_entries,
        get_entry_duplicates,
        get_entry,
        update_entry,
        delete_entry,
        delete_all_entries,
        get_categories_for_entry,
        add_category_to_entry,
        remove_category_from_entry,
        create_category,
        list_categories,
        update_category,
        delete_category,
        get_entries_for_category,
        create_custom_status,
        list_custom_statuses,
        update_custom_status,
        delete_custom_status,
    ],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)
