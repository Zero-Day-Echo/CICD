#!/usr/bin/env python3
"""解析 Git tag：appbackend-v0615 → project=appbackend, version=v0615, image=appbackend:v0615"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse_tag.py <git-tag>", file=sys.stderr)
        return 2

    tag = sys.argv[1].strip()
    if tag.startswith("refs/tags/"):
        tag = tag.removeprefix("refs/tags/")

    config_path = Path(__file__).resolve().parents[1] / "projects.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    pattern = re.compile(config["tag_pattern"])
    match = pattern.fullmatch(tag)
    if not match:
        print(
            f"tag「{tag}」不符合规则 {{project}}-{{version}}，例如 appbackend-v0615",
            file=sys.stderr,
        )
        return 1

    project_key = match.group("project")
    version = match.group("version")
    project = config["projects"].get(project_key)
    if project is None:
        known = ", ".join(sorted(config["projects"]))
        print(f"未知子项目「{project_key}」，已配置: {known}", file=sys.stderr)
        return 1

    image_name = project["image"]
    image_ref = f"{image_name}:{version}"
    print(
        json.dumps(
            {
                "tag": tag,
                "project_key": project_key,
                "version": version,
                "image_name": image_name,
                "image_ref": image_ref,
                "context": project["context"],
                "dockerfile": project["dockerfile"],
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
