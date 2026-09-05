from litestar import Router, delete, get, post, put
from litestar.di import NamedDependency, Provide
from litestar.exceptions import NotFoundException, ValidationException
from litestar.params import FromPath, FromQuery
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.dependencies import BEARER_SECURITY_REQUIREMENT, get_current_user
from backlog_manager_backend.errors import NotFoundError
from backlog_manager_backend.repositories import (
    backlog_entry_repo,
    category_backlog_entry_repo,
    category_repo,
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
from backlog_manager_backend.schemas.user import User

_ENTRY_NOT_FOUND = "Backlog entry not found"
_CATEGORY_NOT_FOUND = "Category not found"


async def _get_owned_entry(session: AsyncSession, entry_id: int, user: User) -> BacklogEntry:
    try:
        entry = await backlog_entry_repo.get_backlog_entry_by_id(session, entry_id)
    except NotFoundError as error:
        raise NotFoundException(_ENTRY_NOT_FOUND) from error
    if entry.user_id != user.id:
        # Same response as a real 404 - existence of another user's
        # resource isn't revealed by a distinct 403.
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


backlog_router = Router(
    path="",
    route_handlers=[
        create_entry,
        list_entries,
        get_entry,
        update_entry,
        delete_entry,
        get_categories_for_entry,
        add_category_to_entry,
        remove_category_from_entry,
        create_category,
        list_categories,
        update_category,
        delete_category,
        get_entries_for_category,
    ],
    dependencies={"current_user": Provide(get_current_user)},
    security=BEARER_SECURITY_REQUIREMENT,
)
