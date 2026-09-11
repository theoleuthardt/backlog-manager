from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.repositories import user_game_price_alert_repo, user_repo
from backlog_manager_backend.schemas.user import CreateUserParams


async def _make_user(session: AsyncSession, email: str = "claimowner@example.com") -> object:
    return await user_repo.create_user(
        session,
        CreateUserParams(username=email.split("@")[0], email=email, password_hash="h"),
    )


async def test_try_claim_alert_succeeds_when_no_prior_alert(session: AsyncSession) -> None:
    user = await _make_user(session)

    claimed = await user_game_price_alert_repo.try_claim_alert(
        session, user.id, 220, Decimal("9.99")
    )

    assert claimed is True
    assert await user_game_price_alert_repo.get_last_alerted_price(
        session, user.id, 220
    ) == Decimal("9.99")


async def test_try_claim_alert_fails_when_price_unchanged(session: AsyncSession) -> None:
    user = await _make_user(session)
    await user_game_price_alert_repo.try_claim_alert(session, user.id, 220, Decimal("9.99"))

    claimed_again = await user_game_price_alert_repo.try_claim_alert(
        session, user.id, 220, Decimal("9.99")
    )

    assert claimed_again is False


async def test_try_claim_alert_succeeds_when_price_changes(session: AsyncSession) -> None:
    user = await _make_user(session)
    await user_game_price_alert_repo.try_claim_alert(session, user.id, 220, Decimal("9.99"))

    claimed = await user_game_price_alert_repo.try_claim_alert(
        session, user.id, 220, Decimal("4.99")
    )

    assert claimed is True
    assert await user_game_price_alert_repo.get_last_alerted_price(
        session, user.id, 220
    ) == Decimal("4.99")


async def test_clear_last_alerted_price_allows_reclaim_at_same_price(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)
    await user_game_price_alert_repo.try_claim_alert(session, user.id, 220, Decimal("9.99"))

    await user_game_price_alert_repo.clear_last_alerted_price(session, user.id, 220)

    assert await user_game_price_alert_repo.get_last_alerted_price(session, user.id, 220) is None
    reclaimed = await user_game_price_alert_repo.try_claim_alert(
        session, user.id, 220, Decimal("9.99")
    )
    assert reclaimed is True


async def test_clear_last_alerted_price_is_a_noop_when_nothing_claimed(
    session: AsyncSession,
) -> None:
    user = await _make_user(session)

    await user_game_price_alert_repo.clear_last_alerted_price(session, user.id, 220)

    assert await user_game_price_alert_repo.get_last_alerted_price(session, user.id, 220) is None
