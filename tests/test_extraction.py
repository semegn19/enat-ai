import json
from unittest.mock import AsyncMock, patch

import pytest

from app.services.extraction import ExtractionService, _parse_json_response


def test_parse_json_response_strips_markdown_fence() -> None:
    raw = '```json\n{"symptoms":[]}\n```'
    assert _parse_json_response(raw) == {"symptoms": []}


@pytest.mark.asyncio
async def test_extraction_validates_symptoms_and_sets_danger_sign() -> None:
    service = ExtractionService()
    llm_payload = {
        "symptoms": [
            {
                "raw_text": "ከባድ ራስ ምታት",
                "category": "severe_headache",
                "duration": {"value": 1, "unit": "day"},
                "severity": "severe",
            }
        ]
    }

    with patch.object(
        service.client,
        "generate_json",
        new=AsyncMock(return_value=json.dumps(llm_payload)),
    ):
        items = await service.extract("ከባድ ራስ ምታት", "symptoms")

    assert len(items) == 1
    assert items[0]["danger_sign"] is True
    assert items[0]["confirmed"] is False
    assert "item_id" in items[0]
    assert "verification_phrase" in items[0]
    assert "ከባድ ራስ ምታት" in items[0]["verification_phrase"]
    assert "1 ቀን" in items[0]["verification_phrase"]


@pytest.mark.asyncio
async def test_extraction_retries_on_invalid_json() -> None:
    service = ExtractionService()
    mock = AsyncMock(side_effect=["not-json", '{"symptoms":[{"raw_text":"ምንም","category":null,"duration":{"value":null,"unit":"unspecified"},"severity":"unspecified"}]}'])
    with patch.object(service.client, "generate_json", new=mock):
        items = await service.extract("ምንም", "symptoms")
    assert len(items) == 1
    assert items[0]["raw_text"] == "ምንም"
    assert items[0]["danger_sign"] is False
    assert mock.await_count == 2


@pytest.mark.asyncio
async def test_extraction_negative_or_fine_symptom_captures_item() -> None:
    service = ExtractionService()
    llm_payload = {"symptoms": []}
    with patch.object(service.client, "generate_json", new=AsyncMock(return_value=json.dumps(llm_payload))):
        items = await service.extract("አይ ምንም ይለኛል", "symptoms")
    assert len(items) == 1
    assert items[0]["raw_text"] == "አይ ምንም ይለኛል"
    assert items[0]["category"] == "no_danger_sign_detected"
    assert items[0]["category_display"] == "ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)"
    assert items[0]["danger_sign"] is False
    assert items[0]["verification_phrase"] == "አይ ምንም ይለኛል — ትክክል ነው?"


@pytest.mark.asyncio
async def test_extraction_raises_after_max_retries() -> None:
    service = ExtractionService()
    with patch.object(
        service.client,
        "generate_json",
        new=AsyncMock(return_value="not-json"),
    ):
        with pytest.raises(ValueError):
            await service.extract("", "symptoms")


@pytest.mark.asyncio
async def test_extraction_mild_symptom_overrides_danger_sign_to_false() -> None:
    service = ExtractionService()
    # Even if LLM erroneously outputs a category for a mild symptom,
    # server-side guard forces category="no_danger_sign_detected" and danger_sign=False.
    llm_payload = {
        "symptoms": [
            {
                "raw_text": "ቀላል የድካም ስሜት",
                "category": "severe_weakness_or_backache",
                "duration": {"value": None, "unit": "unspecified"},
                "severity": "mild",
            }
        ]
    }

    with patch.object(
        service.client,
        "generate_json",
        new=AsyncMock(return_value=json.dumps(llm_payload)),
    ):
        items = await service.extract("ቀላል የድካም ስሜት", "symptoms")

    assert len(items) == 1
    assert items[0]["category"] == "no_danger_sign_detected"
    assert items[0]["category_display"] == "ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)"
    assert items[0]["danger_sign"] is False
    assert items[0]["verification_phrase"] == "ቀላል የድካም ስሜት — ትክክል ነው?"


@pytest.mark.asyncio
async def test_extraction_supplement_unknown_name_formats_clean_amharic_phrase() -> None:
    service = ExtractionService()
    llm_payload = {
        "supplement_check": {
            "raw_text": "አዎ ወስቻለሁ።",
            "supplement_name": "unknown",
            "taken_today": True,
        }
    }

    with patch.object(
        service.client,
        "generate_json",
        new=AsyncMock(return_value=json.dumps(llm_payload)),
    ):
        items = await service.extract("አዎ ወስቻለሁ።", "supplement")

    assert len(items) == 1
    assert items[0]["verification_phrase"] == "ተጨማሪ ምግብ ዛሬ ወስደዋል — ትክክል ነው?"
