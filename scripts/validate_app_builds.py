#!/usr/bin/env python3
"""Keep mobile build numbers and pinned API versions aligned with the public manifest."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def one(pattern: str, text: str, label: str) -> str:
    values = set(re.findall(pattern, text, flags=re.MULTILINE))
    if len(values) != 1:
        raise ValueError(f"Expected one {label}, found {sorted(values)}")
    return values.pop()


def source_builds(root: Path = ROOT) -> dict[str, dict[str, str]]:
    android_build = (root / "android/app/build.gradle.kts").read_text()
    android_api = (
        root
        / "android/app/src/main/java/org/warringtontownship/parks/android/data/network/TrailsApiService.kt"
    ).read_text()
    ios_project = (root / "ios/WarringtonTalkingTrails.xcodeproj/project.pbxproj").read_text()
    ios_api = (root / "ios/WarringtonTalkingTrails/Service/Utils.swift").read_text()

    return {
        "android": {
            "appId": one(r'applicationId\s*=\s*"([^"]+)"', android_build, "Android app ID"),
            "version": one(r'versionName\s*=\s*"([^"]+)"', android_build, "Android version name"),
            "build": one(r"versionCode\s*=\s*(\d+)", android_build, "Android version code"),
            "apiVersion": one(r'const val VERSION\s*=\s*"([^"]+)"', android_api, "Android API version"),
        },
        "ios": {
            "appId": one(
                r"PRODUCT_BUNDLE_IDENTIFIER = (org\.warringtontownship\.lionspride);",
                ios_project,
                "iOS app ID",
            ),
            "version": one(r"MARKETING_VERSION = ([^;]+);", ios_project, "iOS version"),
            "build": one(r"CURRENT_PROJECT_VERSION = ([^;]+);", ios_project, "iOS build"),
            "apiVersion": one(r'API_MAJOR_VERSION\s*=\s*"([^"]+)"', ios_api, "iOS API version"),
        },
    }


def validate(root: Path = ROOT) -> list[str]:
    manifest_path = root / "server/api/app-builds.json"
    manifest = json.loads(manifest_path.read_text())
    published = json.loads((root / "server/api/versions.json").read_text())
    published_versions = {f"v{item['version']}" for item in published["versions"]}
    errors: list[str] = []

    if manifest.get("manifestVersion") != 1:
        errors.append("app-builds.json manifestVersion must be 1")

    current = manifest.get("currentBuilds", {})
    for platform, source in source_builds(root).items():
        recorded = current.get(platform)
        if not isinstance(recorded, dict):
            errors.append(f"app-builds.json is missing currentBuilds.{platform}")
            continue
        for field, expected in source.items():
            actual = str(recorded.get(field, ""))
            if actual != expected:
                errors.append(
                    f"{platform} {field} is {expected!r} in source but {actual!r} in app-builds.json"
                )
        api_version = source["apiVersion"]
        if api_version not in published_versions:
            errors.append(f"{platform} pins unpublished API version {api_version}")
        base = f"https://trails.warringtoneac.org/api/{api_version}"
        if recorded.get("data") != f"{base}/trails.json":
            errors.append(f"{platform} data URL does not match {api_version}")
        if recorded.get("kml") != f"{base}/talking-trails.kml":
            errors.append(f"{platform} KML URL does not match {api_version}")

    return errors


def main() -> int:
    try:
        errors = validate()
    except (OSError, ValueError, json.JSONDecodeError, KeyError) as exc:
        print(f"Build/API manifest validation failed: {exc}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Mobile build numbers and API pins match server/api/app-builds.json.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
