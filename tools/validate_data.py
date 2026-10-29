#!/usr/bin/env python3
"""Validate every faction file in data/factions/ without opening Godot.

Checks that JSON parses and that every cross-reference (units, buildings,
requirements, drop-offs, AI build order) points at something that exists.
Mirrors GameData.validate_faction() in scripts/autoload/game_data.gd.

Usage: python3 tools/validate_data.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RESOURCES = {"gold", "wood", "stone"}
ROLES = {"builder", "melee", "ranged", "heavy", "vehicle", "flyer"}


def validate(f: dict) -> list[str]:
    errors = []
    units = f.get("units", {})
    buildings = f.get("buildings", {})
    for key in ("id", "name", "color", "hq", "builder", "supply_building"):
        if key not in f:
            errors.append(f'missing "{key}"')
    if f.get("hq") not in buildings:
        errors.append(f'hq "{f.get("hq")}" is not a building')
    if f.get("builder") not in units:
        errors.append(f'builder "{f.get("builder")}" is not a unit')
    if f.get("supply_building") not in buildings:
        errors.append(f'supply_building "{f.get("supply_building")}" is not a building')
    for uid in f.get("starting_units", []):
        if uid not in units:
            errors.append(f'starting unit "{uid}" does not exist')

    trained = {uid for b in buildings.values() for uid in b.get("trains", [])}
    for uid, u in units.items():
        if u.get("role") not in ROLES:
            errors.append(f'unit {uid} has unknown role "{u.get("role")}"')
        for req in u.get("requires", []):
            if req not in buildings:
                errors.append(f'unit {uid} requires unknown building "{req}"')
        for r in u.get("cost", {}):
            if r not in RESOURCES:
                errors.append(f'unit {uid} costs unknown resource "{r}"')
        if uid not in trained:
            errors.append(f"unit {uid} is not trained by any building")
        if u.get("role") == "builder" and u.get("carry_capacity", 0) <= 0:
            errors.append(f"builder {uid} needs a positive carry_capacity")

    for bid, b in buildings.items():
        size = b.get("size")
        if not (isinstance(size, list) and len(size) == 2):
            errors.append(f'building {bid} needs "size": [w, h]')
        for req in b.get("requires", []):
            if req not in buildings:
                errors.append(f'building {bid} requires unknown building "{req}"')
        for uid in b.get("trains", []):
            if uid not in units:
                errors.append(f'building {bid} trains unknown unit "{uid}"')
        for r in b.get("drop_off", []):
            if r not in RESOURCES:
                errors.append(f'building {bid} accepts unknown resource "{r}"')
        for r in b.get("cost", {}):
            if r not in RESOURCES:
                errors.append(f'building {bid} costs unknown resource "{r}"')

    hq = buildings.get(f.get("hq"), {})
    if f.get("builder") not in hq.get("trains", []):
        errors.append("the hq must be able to train the builder")
    if not set(hq.get("drop_off", [])) >= RESOURCES:
        errors.append("the hq should accept every resource as a drop-off")

    ai = f.get("ai", {})
    for bid in ai.get("build_order", []):
        if bid not in buildings:
            errors.append(f'ai build_order has unknown building "{bid}"')
    for uid in ai.get("army", []):
        if uid not in units:
            errors.append(f'ai army has unknown unit "{uid}"')
    return errors


def main() -> int:
    files = sorted((ROOT / "data" / "factions").glob("*.json"))
    if not files:
        print("No faction files found in data/factions/")
        return 1
    failed = False
    ids = set()
    for path in files:
        try:
            faction = json.loads(path.read_text())
        except json.JSONDecodeError as e:
            print(f"FAIL {path.name}: invalid JSON: {e}")
            failed = True
            continue
        errors = validate(faction)
        if faction.get("id") in ids:
            errors.append(f'duplicate faction id "{faction.get("id")}"')
        ids.add(faction.get("id"))
        if errors:
            failed = True
            print(f"FAIL {path.name}")
            for err in errors:
                print(f"     - {err}")
        else:
            print(f"ok   {path.name} ({len(faction['units'])} units, {len(faction['buildings'])} buildings)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
