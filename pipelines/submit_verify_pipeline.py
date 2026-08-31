#!/usr/bin/env python3
"""Submit verify_opencode_pipeline to the project pipeline server."""

from __future__ import annotations

import os
import sys

from kfp import Client

from verify_opencode_pipeline import verify_opencode_pipeline


def main() -> int:
    namespace = os.environ.get("DSP_NAMESPACE", "custom-workbench-demo")
    host = os.environ.get(
        "DSP_HOST",
        f"https://ds-pipeline-dspa.{namespace}.svc:8443",
    )
    run_name = os.environ.get("PIPELINE_RUN_NAME", "verify-opencode-manual")

    client = Client(host=host, namespace=namespace, existing=True)
    run = client.create_run_from_pipeline_func(
        verify_opencode_pipeline,
        arguments={},
        run_name=run_name,
    )
    print(f"Submitted run: {run.run_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
