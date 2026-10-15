"""Register the private Fish reference once the local API is healthy."""

from __future__ import annotations

import os
from pathlib import Path

import requests


API_URL = f"http://127.0.0.1:{os.getenv('FISH_API_PORT', '8080')}"


def required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"{name} is required when REQUIRE_REFERENCE=1")
    return value


def main() -> None:
    if os.getenv("REQUIRE_REFERENCE", "0") != "1":
        print("Reference registration skipped (REQUIRE_REFERENCE is not 1).", flush=True)
        return

    reference_id = required("FISH_REFERENCE_ID")
    audio_path = Path(required("FISH_REFERENCE_AUDIO"))
    transcript_path = Path(required("FISH_REFERENCE_TRANSCRIPT"))
    if not audio_path.is_file() or not transcript_path.is_file():
        raise RuntimeError("Reference audio and transcript must be mounted as readable files")

    response = requests.get(f"{API_URL}/v1/references/list?format=json", timeout=15)
    response.raise_for_status()
    if reference_id in response.json().get("reference_ids", []):
        print(f"Reference '{reference_id}' already exists.", flush=True)
        return

    with audio_path.open("rb") as audio_file:
        response = requests.post(
            f"{API_URL}/v1/references/add?format=json",
            data={"id": reference_id, "text": transcript_path.read_text(encoding="utf-8").strip()},
            files={"audio": (audio_path.name, audio_file, "audio/wav")},
            timeout=60,
        )
    response.raise_for_status()
    print(f"Registered reference '{reference_id}'.", flush=True)


if __name__ == "__main__":
    main()
