from backlog_manager_backend.csv.status_mapping import normalize_status


def test_empty_status_defaults_to_not_started() -> None:
    result = normalize_status("")

    assert result.status == "Not Started"
    assert result.note is None


def test_finished_maps_to_completed() -> None:
    result = normalize_status("Finished")

    assert result.status == "Completed"
    assert result.note is None


def test_finished_with_trailing_space_maps_to_completed() -> None:
    assert normalize_status("Finished ").status == "Completed"


def test_playing_maps_to_in_progress() -> None:
    result = normalize_status("Playing")

    assert result.status == "In Progress"
    assert result.note is None


def test_dropped_maps_to_dropped() -> None:
    result = normalize_status("Dropped")

    assert result.status == "Dropped"
    assert result.note is None


def test_finished_with_qualifier_stays_completed_and_keeps_qualifier_as_note() -> None:
    result = normalize_status("Finished (Replay Needed)")

    assert result.status == "Completed"
    assert result.note == "(Replay Needed)"


def test_playing_with_qualifier_stays_in_progress_and_keeps_qualifier_as_note() -> None:
    result = normalize_status("Playing (Backseat)")

    assert result.status == "In Progress"
    assert result.note == "(Backseat)"


def test_dropped_with_qualifier_stays_dropped_and_keeps_qualifier_as_note() -> None:
    result = normalize_status("Dropped (For now)")

    assert result.status == "Dropped"
    assert result.note == "(For now)"


def test_unrecognized_status_passes_through_as_is() -> None:
    result = normalize_status("On Hold")

    assert result.status == "On Hold"
    assert result.note is None
