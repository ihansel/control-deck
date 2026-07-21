#!/usr/bin/env python3
from pathlib import Path
import runpy

runpy.run_path(
    str(
        Path(__file__).resolve().parents[1]
        / "Sources"
        / "ControlDeck"
        / "Resources"
        / "control_deck_mcp.py"
    ),
    run_name="__main__",
)
