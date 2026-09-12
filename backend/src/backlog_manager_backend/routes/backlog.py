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

_ENTRY_NOT_FOUND = "Backlog entry not found"
_CATEGORY_NOT_FOUND = "Category not found"
_STATUS_NOT_FOUND = "Custom status not found"
DEFAULT_STATUSES = ("Not Started", "In Progress", "Completed", "On Hold", "Dropped")
_STATUS_NAME_MAX_LENGTH = 20


class _StatusConflictException(ClientException):
    """Documents the 409 a duplicate custom-status name raises, distinct
    from ClientException's default 400 so it shows up in the OpenAPI
    response union via the handlers' `raises=` declarations."""

    status_code = HTTP_409_CONFLICT


async def _get_owned_entry(session: AsyncSession, entry_id: int, user: User) -> BacklogEntry:
    """Raises the same response as a real 404 when the entry belongs to
    another user - existence of another user's resource isn't revealed
    by a distinct 403."""
    try:
        entry = await backlog_entry_repo.get_backlog_entry_by_id(session, entry_id)
    except NotFoundError as error:
        raise NotFoundException(_ENTRY_NOT_FOUND) from error
    if entry.user_id != user.id:
        raise NotFoundException(_ENTRY_NOT_FOUND)
    return entry


async def _get_owned_category(session: AsyncSession, category_id: int, user: User) -> Category:
    categories = await category_repo.get_categories_by_user(session, user.id)
    category = next((c for c in categories if c.category_id == category_id), None)
    if category is None:
        raise NotFoundException(_CATEGORY_NOT_FOUND)
    return category


def _join_tags(field_name: str, values: list[str]) -> str:
    """The DB stores genre/platform as one ", "-joined column (unchanged
    from the original schema), so a value containing that delimiter
    would silently split back into multiple values on the next read -
    rejected here rather than persisted lossily."""
    for value in values:
        if "," in value:
            raise ValidationException(f"{field_name} entries must not contain a comma: {value!r}")
    return ", ".join(values)


@post("/api/backlog/entries", status_code=201)
async def create_entry(
    data: CreateBacklogEntryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> BacklogEntryResponse:
    entry = await backlog_entry_repo.create_backlog_entry(
        db_session,
        CreateBacklogEntryParams(
            user_id=current_user.id,
            title=data.title,
            genre=_join_tags("genre", data.genre),
            platform=_join_tags("platform", data.platform),
            status=data.status,
            owned=data.owned,
            interest=data.interest,
            release_date=data.release_date,
            image_link=data.image_link,
            main_time=data.main_time,
            main_plus_extra_time=data.main_plus_extra_time,
            completion_time=data.completion_time,
            playtime=data.playtime,
            steam_app_id=data.steam_app_id,
            review_stars=round(data.review_stars) if data.review_stars is not None else None,
            review=data.review,
            note=data.note,
        ),
    )
    return BacklogEntryResponse.from_entry(entry)


@get("/api/backlog/entries")
async def list_entries(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
    status: FromQuery[str | None] = None,
) -> list[BacklogEntryResponse]:
    if status is not None:
        entries = await backlog_entry_repo.get_backlog_entries_by_status(
            db_session, GetEntriesByStatusParams(user_id=current_user.id, status=status)
        )
    else:
        entries = await backlog_entry_repo.get_backlog_entries_by_user(db_session, current_user.id)
    return [BacklogEntryResponse.from_entry(entry) for entry in entries]


@get("/api/backlog/entries/{entry_id:int}")
async def get_entry(
    entry_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> BacklogEntryResponse:
    entry = await _get_owned_entry(db_session, entry_id, current_user)
    return BacklogEntryResponse.from_entry(entry)


@put("/api/backlog/entries/{entry_id:int}")
async def update_entry(
    entry_id: FromPath[int],
    data: UpdateBacklogEntryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> BacklogEntryResponse:
    await _get_owned_entry(db_session, entry_id, current_user)

    review_stars = data.review_stars
    if isinstance(review_stars, float):
        review_stars = round(review_stars)

    entry = await backlog_entry_repo.update_backlog_entry(
        db_session,
        UpdateBacklogEntryParams(
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
            main_time=data.main_time,
            main_plus_extra_time=data.main_plus_extra_time,
            completion_time=data.completion_time,
            playtime=data.playtime,
            steam_app_id=data.steam_app_id,
            review_stars=review_stars,
            review=data.review,
            note=data.note,
        ),
    )
    return BacklogEntryResponse.from_entry(entry)


@delete("/api/backlog/entries/{entry_id:int}")
async def delete_entry(
    entry_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    await _get_owned_entry(db_session, entry_id, current_user)
    await backlog_entry_repo.delete_backlog_entry(db_session, entry_id)


@delete("/api/backlog/entries", status_code=200)
async def delete_all_entries(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> int:
    """Bulk variant of delete_entry - permanently deletes every backlog
    entry of the caller (category associations cascade). Returns the
    number of entries removed."""
    return await backlog_entry_repo.delete_backlog_entries_by_user(db_session, current_user.id)


@get("/api/backlog/entries/{entry_id:int}/categories")
async def get_categories_for_entry(
    entry_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[CategoryResponse]:
    await _get_owned_entry(db_session, entry_id, current_user)
    categories = await category_repo.get_categories_for_backlog_entry(db_session, entry_id)
    return [CategoryResponse.from_category(category) for category in categories]


@post("/api/backlog/entries/{entry_id:int}/categories/{category_id:int}", status_code=201)
async def add_category_to_entry(
    entry_id: FromPath[int],
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    await _get_owned_entry(db_session, entry_id, current_user)
    await _get_owned_category(db_session, category_id, current_user)
    await category_backlog_entry_repo.add_category_to_backlog_entry(
        db_session,
        CategoryBacklogAssociationParams(category_id=category_id, backlog_entry_id=entry_id),
    )


@delete("/api/backlog/entries/{entry_id:int}/categories/{category_id:int}")
async def remove_category_from_entry(
    entry_id: FromPath[int],
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    await _get_owned_entry(db_session, entry_id, current_user)
    await _get_owned_category(db_session, category_id, current_user)
    await category_backlog_entry_repo.remove_backlog_entry_from_category(
        db_session,
        CategoryBacklogAssociationParams(category_id=category_id, backlog_entry_id=entry_id),
    )


@post("/api/backlog/categories", status_code=201)
async def create_category(
    data: CreateCategoryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> CategoryResponse:
    category = await category_repo.create_category(
        db_session,
        CreateCategoryParams(
            user_id=current_user.id,
            category_name=data.category_name,
            color=data.color,
            description=data.description,
        ),
    )
    return CategoryResponse.from_category(category)


@get("/api/backlog/categories")
async def list_categories(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[CategoryResponse]:
    categories = await category_repo.get_categories_by_user(db_session, current_user.id)
    return [CategoryResponse.from_category(category) for category in categories]


@put("/api/backlog/categories/{category_id:int}")
async def update_category(
    category_id: FromPath[int],
    data: UpdateCategoryRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> CategoryResponse:
    await _get_owned_category(db_session, category_id, current_user)
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


@delete("/api/backlog/categories/{category_id:int}")
async def delete_category(
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    await _get_owned_category(db_session, category_id, current_user)
    await category_repo.delete_category(db_session, category_id)


@get("/api/backlog/categories/{category_id:int}/entries")
async def get_entries_for_category(
    category_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[BacklogEntryResponse]:
    await _get_owned_category(db_session, category_id, current_user)
    entries = await backlog_entry_repo.get_backlog_entries_for_category(db_session, category_id)
    return [BacklogEntryResponse.from_entry(entry) for entry in entries]


def _validated_status_name(raw_name: str) -> str:
    name = raw_name.strip()
    if not name:
        raise ValidationException("Status name must not be empty")
    if len(name) > _STATUS_NAME_MAX_LENGTH:
        raise ValidationException(
            f"Status name must be at most {_STATUS_NAME_MAX_LENGTH} characters"
        )
    return name


async def _get_owned_status(
    session: AsyncSession, status_id: int, user: User
) -> CustomStatus:
    try:
        status = await custom_status_repo.get_custom_status_by_id(session, status_id)
    except NotFoundError as error:
        raise NotFoundException(_STATUS_NOT_FOUND) from error
    if status.user_id != user.id:
        raise NotFoundException(_STATUS_NOT_FOUND)
    return status


@post(
    "/api/backlog/statuses",
    status_code=201,
    raises=[ValidationException, _StatusConflictException],
)
async def create_custom_status(
    data: CreateCustomStatusRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> CustomStatusResponse:
    name = _validated_status_name(data.name)
    if name in DEFAULT_STATUSES:
        raise ValidationException(f"{name!r} is already a default status")
    try:
        status = await custom_status_repo.create_custom_status(
            db_session, CreateCustomStatusParams(user_id=current_user.id, name=name)
        )
    except ConflictError as error:
        raise _StatusConflictException(f"A status named {name!r} already exists") from error
    return CustomStatusResponse.from_status(status)


@get("/api/backlog/statuses")
async def list_custom_statuses(
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> list[CustomStatusResponse]:
    statuses = await custom_status_repo.get_custom_statuses_by_user(
        db_session, current_user.id
    )
    return [CustomStatusResponse.from_status(status) for status in statuses]


@put(
    "/api/backlog/statuses/{status_id:int}",
    raises=[NotFoundException, ValidationException, _StatusConflictException],
)
async def update_custom_status(
    status_id: FromPath[int],
    data: UpdateCustomStatusRequest,
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> CustomStatusResponse:
    await _get_owned_status(db_session, status_id, current_user)
    name = _validated_status_name(data.name)
    if name in DEFAULT_STATUSES:
        raise ValidationException(f"{name!r} is already a default status")
    try:
        status = await custom_status_repo.update_custom_status(
            db_session, UpdateCustomStatusParams(status_id=status_id, name=name)
        )
    except ConflictError as error:
        raise _StatusConflictException(f"A status named {name!r} already exists") from error
    return CustomStatusResponse.from_status(status)


@delete("/api/backlog/statuses/{status_id:int}", raises=[NotFoundException])
async def delete_custom_status(
    status_id: FromPath[int],
    db_session: NamedDependency[AsyncSession],
    current_user: NamedDependency[User],
) -> None:
    await _get_owned_status(db_session, status_id, current_user)
    await custom_status_repo.delete_custom_status(db_session, status_id)


backlog_router = Router(
    path="",
    route_handlers=[
        create_entry,
        list_entries,
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
