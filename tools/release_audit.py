#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "0.8.1-rc5"
SUITS = ("bastoni", "coppe", "denari", "spade")

errors: list[str] = []
notes: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read(path: str) -> str:
    file = ROOT / path
    require(file.is_file(), f"missing required file: {path}")
    return file.read_text(encoding="utf-8") if file.is_file() else ""


project = read("project.godot")
match = re.search(r'config/version="([^"]+)"', project)
require(match is not None, "project.godot has no application version")
if match:
    require(match.group(1) == EXPECTED_VERSION, f"expected version {EXPECTED_VERSION}, found {match.group(1)}")

preset = read("export_presets.cfg")
require('platform="Web"' in preset, "Web export preset missing")
require('variant/thread_support=false' in preset, "Web build must remain single-threaded for static hosting")
require('vram_texture_compression/for_desktop=true' in preset, "desktop VRAM compression disabled")
require('vram_texture_compression/for_mobile=true' in preset, "mobile VRAM compression disabled")
# Godot built-in PWA stays off: we generate our own versioned service worker/manifest in postprocess_web.py.
require('progressive_web_app/enabled=false' in preset, "Godot built-in PWA must stay off; custom versioned PWA is generated after export")

required_docs = ["README.md", "ASSET_NOTICE.md", "HANDOFF.md", "PRODUCTION_CHECKLIST.md", "QA_CHECKLIST.md", "RELEASE_RUNBOOK.md", "CHANGELOG.md", "DEVICE_QA.md", "PLAYTEST_PLAN.md", "MONITORING.md", "SUPPORT.md", "BRAND.md", "PRIVACY.md", "PWA.md", "VARIANTS.md", "SINGLE_PLAYER_PRODUCTION.md"]
for path in required_docs:
    require((ROOT / path).is_file(), f"missing release documentation: {path}")

card_files: list[Path] = []
for suit in SUITS:
    suit_dir = ROOT / "assets" / "cards" / "napoletane" / suit
    for rank in range(1, 11):
        path = suit_dir / f"{rank:02d}.svg"
        require(path.is_file(), f"missing card asset: {path.relative_to(ROOT)}")
        if path.is_file():
            card_files.append(path)
require(len(card_files) == 40, f"expected 40 card assets, found {len(card_files)}")
require((ROOT / "assets/cards/retro.svg").is_file(), "missing card back")

for audio in ("card_play.wav", "card_take.wav", "shuffle.wav", "win.wav", "lose.wav"):
    require((ROOT / "assets/audio" / audio).is_file(), f"missing audio asset: {audio}")

main = read("scripts/main.gd")
card_view = read("scripts/card_view.gd")
self_test = read("scripts/self_test.gd")
require("func _animate_initial_deal()" in main, "initial deal animation missing")
require("func _animate_initial_trump_reveal()" in main, "trump reveal animation missing")
require("func _warm_runtime_assets()" in main, "runtime asset warmup missing")
require("func _build_tutorial_overlay()" in main, "tutorial overlay missing")
require("func _build_restart_dialog()" in main, "restart confirmation missing")
require("func _record_ai_feedback" in main, "post-game AI feedback missing")
require("func _open_feedback" in main, "support/feedback action missing")
require("func _run_web_qa" in main, "browser QA bridge missing")
require("get_visual_global_rotation" in card_view, "CardView final-pose helper missing")
require("_assert_live_invariants" in self_test, "live invariant simulation checks missing")
require("_test_persistence_roundtrip" in self_test, "persistence roundtrip test missing")
require((ROOT / "package.json").is_file(), "Playwright package.json missing")
require((ROOT / "playwright.config.cjs").is_file(), "Playwright config missing")
require((ROOT / "tests/browser/game.spec.cjs").is_file(), "browser QA test missing")
require((ROOT / "tests/browser/pwa.spec.cjs").is_file(), "PWA offline QA test missing")
require((ROOT / "tools/postprocess_web.py").is_file(), "Web postprocess/monitoring hook missing")
require((ROOT / "scripts/four_player_engine.gd").is_file(), "four-player engine missing")
require((ROOT / "scripts/four_player.gd").is_file(), "four-player UI missing")
require((ROOT / "scenes/four_player.tscn").is_file(), "four-player scene missing")
require("_test_four_player_mode" in self_test, "four-player simulation test missing")
for icon in ("icon-192.png", "icon-512.png", "apple-touch-icon.png"):
    require((ROOT / "assets" / "pwa" / icon).is_file(), f"PWA icon missing: {icon}")
postprocess = read("tools/postprocess_web.py")
require("service-worker.js" in postprocess, "versioned PWA service worker generation missing")
require("manifest.webmanifest" in postprocess, "PWA manifest generation missing")
require((ROOT / ".github/ISSUE_TEMPLATE/bug_report.yml").is_file(), "bug report template missing")
require((ROOT / ".github/ISSUE_TEMPLATE/playtest_feedback.yml").is_file(), "playtest template missing")

asset_notice = read("ASSET_NOTICE.md").lower()
require("prima di pubblicare" in asset_notice or "before publishing" in asset_notice, "asset licensing warning missing")

if errors:
    print("RELEASE AUDIT: FAILED")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("RELEASE AUDIT: OK")
print(f" - version: {EXPECTED_VERSION}")
print(" - 40/40 card assets present")
print(" - Web single-thread export configured")
print(" - custom PWA manifest/service worker with build-versioned cache configured")
print(" - production docs present")
print(" - initial deal + onboarding + restart guard present")
print(" - cross-browser QA + feedback + monitoring hooks present")
print(" - persistence roundtrip test present")
print(" - four-player teams engine/UI and simulation tests present")
