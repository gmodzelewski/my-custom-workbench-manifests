#!/usr/bin/env python3
"""Minimal KFP pipeline: verify OpenCode is available in the custom runtime image."""

from __future__ import annotations

import os

from kfp import dsl
from kfp.dsl import component

RUNTIME_IMAGE = os.environ.get(
    "QUAY_RUNTIME_IMAGE",
    "quay.io/modzelewski/custom-workbench-opencode-runtime:1.0",
)


@component(base_image=RUNTIME_IMAGE)
def verify_opencode() -> str:
    import subprocess

    result = subprocess.run(
        ["opencode", "--version"],
        check=True,
        capture_output=True,
        text=True,
    )
    version = result.stdout.strip()
    print(f"OpenCode version: {version}")
    return version


@dsl.pipeline(
    name="verify-opencode-runtime",
    description="Confirms the custom runtime image includes the OpenCode CLI.",
)
def verify_opencode_pipeline():
    verify_opencode()


if __name__ == "__main__":
    from kfp.compiler import Compiler

    Compiler().compile(verify_opencode_pipeline, "verify-opencode-runtime.yaml")
    print("Wrote verify-opencode-runtime.yaml")
