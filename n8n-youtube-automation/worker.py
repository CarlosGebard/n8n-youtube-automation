"""Vast PyWorker configuration for the local Fish Speech API server."""

from __future__ import annotations

import os

from vastai import BenchmarkConfig, HandlerConfig, LogActionConfig, Worker, WorkerConfig

from contract import request_parser


def workload(payload: dict) -> float:
    """A conservative proxy for sequential TTS work: UTF-8 input bytes."""
    return float(len(payload["text"].encode("utf-8")))


def benchmark_request() -> dict:
    # Do not use the private voice reference during benchmarking.
    return {"text": "This is a short Fish Audio readiness benchmark.", "format": "wav"}


config = WorkerConfig(
    model_server_url="http://127.0.0.1",
    model_server_port=int(os.getenv("FISH_API_PORT", "8080")),
    model_log_file=os.getenv("FISH_LOG_FILE", "/var/log/fish-speech/server.log"),
    model_healthcheck_url="/v1/health",
    handlers=[
        HandlerConfig(
            route="/v1/tts",
            request_parser=request_parser,
            workload_calculator=workload,
            # S2-Pro on one 24 GB GPU is deliberately serialized until measured.
            allow_parallel_requests=False,
            max_queue_time=600.0,
            benchmark_config=BenchmarkConfig(generator=benchmark_request, runs=1, concurrency=1),
        )
    ],
    log_action_config=LogActionConfig(
        on_load=["Models warmed up."],
        on_error=["Failed to generate speech", "Traceback (most recent call last):"],
        on_info=["Loading", "Downloading"],
    ),
)


if __name__ == "__main__":
    Worker(config).run()
