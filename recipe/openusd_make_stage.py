#!/usr/bin/env python
"""
openusd_make_stage.py
----------------------------------------------------------
Author a minimal but fully valid USD stage so the OpenUSD command-line
tools (usdcat, usdchecker) can be exercised against the installed
layout. The stage carries every piece of stage metadata that
usdchecker requires: a defaultPrim, metersPerUnit and upAxis.

Exit 0  - when the stage was written and reads back as authored.
Exit 1  - when the stage could not be authored or read back.
Exit 2  - bad invocation (missing or extra argument).

Usage:
    python openusd_make_stage.py <stage.usda>
"""

import sys

from pxr import Usd, UsdGeom


def main() -> int:
    # ------------------------- argument parsing -------------------------
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <stage.usda>", file=sys.stderr)
        return 2

    filename = sys.argv[1]

    # --------------------------- author stage ---------------------------
    stage = Usd.Stage.CreateNew(filename)
    if stage is None:
        print(f"Error: could not create stage '{filename}'.", file=sys.stderr)
        return 1

    world = UsdGeom.Xform.Define(stage, "/World")
    stage.SetDefaultPrim(world.GetPrim())
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    stage.GetRootLayer().Save()

    # ---------------------------- verify stage --------------------------
    reopened = Usd.Stage.Open(filename)
    if reopened is None:
        print(f"Error: could not open stage '{filename}'.", file=sys.stderr)
        return 1

    default_prim = reopened.GetDefaultPrim()
    if (
        not reopened.GetPrimAtPath("/World").IsValid()
        or str(default_prim.GetPath()) != "/World"
        or reopened.GetMetadata(UsdGeom.Tokens.metersPerUnit) != 1.0
        or reopened.GetMetadata(UsdGeom.Tokens.upAxis) != UsdGeom.Tokens.y
    ):
        print(f"Error: stage '{filename}' did not round-trip correctly.",
              file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
