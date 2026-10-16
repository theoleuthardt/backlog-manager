import msgspec

NOT_OWNED_STATUS = "Not Owned"
_STARTED_STATUS = "Not Started"


def couple_status_and_ownership(
    current_status: str,
    status: str | msgspec.UnsetType,
    owned: bool | msgspec.UnsetType,
) -> tuple[str | msgspec.UnsetType, bool | msgspec.UnsetType]:
    """Keeps the status "Not Owned" and the owned flag of an entry in step
    when a user changes only one of them: moving a game to "Not Owned" marks
    it as not owned, moving it out of "Not Owned" marks it as owned, marking
    a game as not owned moves it to "Not Owned", and marking a "Not Owned"
    game as owned starts it ("Not Started"). A request that sets both
    decides for itself and is kept as sent, and any other change leaves both
    alone. Only user edits go through this; the Steam and CSV imports set the
    two fields themselves."""
    status_given = isinstance(status, str)
    owned_given = isinstance(owned, bool)
    if status_given and not owned_given:
        if status == NOT_OWNED_STATUS:
            return status, False
        if current_status == NOT_OWNED_STATUS:
            return status, True
    if owned_given and not status_given:
        if owned is False and current_status != NOT_OWNED_STATUS:
            return NOT_OWNED_STATUS, owned
        if owned is True and current_status == NOT_OWNED_STATUS:
            return _STARTED_STATUS, owned
    return status, owned
