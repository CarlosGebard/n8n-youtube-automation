"""The JSON contract accepted from Vast and forwarded to Fish Speech."""

from __future__ import annotations

from typing import Any


def request_parser(request: dict[str, Any]) -> dict[str, Any]:
    """Accept Vast's optional ``input`` wrapper and validate the minimum TTS shape."""
    payload = request.get("input", request)
    if not isinstance(payload, dict):
        raise ValueError("Request body must be a JSON object")

    text = payload.get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("'text' must be a non-empty string")

    # Fish validates optional sampling parameters. Keep them intact so n8n can use
    # the official field names without this proxy becoming another API surface.
    return payload
