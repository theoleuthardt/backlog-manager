import pytest


@pytest.fixture
def proxy_responses(monkeypatch: pytest.MonkeyPatch) -> dict:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "enable_docs", True)
    schema = create_app().openapi_schema.to_schema()
    return schema["paths"]["/api/images/proxy"]["get"]["responses"]


def test_the_image_response_is_documented_as_binary_image_data(proxy_responses: dict) -> None:
    content = proxy_responses["200"]["content"]

    assert set(content) == {"image/*"}
    assert content["image/*"]["schema"]["type"] == "string"


def test_the_description_names_the_supported_image_types(proxy_responses: dict) -> None:
    description = proxy_responses["200"]["description"]

    for content_type in ("image/jpeg", "image/png", "image/webp", "image/gif", "image/avif"):
        assert content_type in description


def test_not_modified_is_documented(proxy_responses: dict) -> None:
    assert "304" in proxy_responses


@pytest.mark.parametrize("status_code", ["400", "404"])
def test_the_errors_are_documented_as_plain_text(proxy_responses: dict, status_code: str) -> None:
    assert set(proxy_responses[status_code]["content"]) == {"text/plain"}
