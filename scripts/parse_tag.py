#!/usr/bin/env python3
"""解析 Git tag。

单项目: appbackend-v061201 → project=appbackend, version=v061201
全量:   all-v061201      → mode=all，展开 projects.json 中全部子项目（同版本号）
平台:   services-v061201 → mode=services，仅 appbackend/agentapi/managefront/importservice

版本号约定 v[mmdd][no]：v061201 = 6 月 12 日第 1 次编译。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ALL_TAG_PATTERN = re.compile(r"^all-(?P<version>v[0-9A-Za-z.]+)$")
SERVICES_TAG_PATTERN = re.compile(r"^services-(?P<version>v[0-9A-Za-z.]+)$")

DEFAULT_SERVICE_PROJECT_KEYS = (
    "appbackend",
    "agentapi",
    "managefront",
    "importservice",
)


def load_config() -> dict[str, Any]:
    config_path = Path(__file__).resolve().parents[1] / "projects.json"
    return json.loads(config_path.read_text(encoding="utf-8"))


def normalize_tag(raw: str) -> str:
    tag = raw.strip()
    if tag.startswith("refs/tags/"):
        tag = tag.removeprefix("refs/tags/")
    return tag


def project_entry(project_key: str, version: str, project: dict[str, Any]) -> dict[str, Any]:
    image_name = project["image"]
    entry: dict[str, Any] = {
        "project_key": project_key,
        "version": version,
        "image_name": image_name,
        "image_ref": f"{image_name}:{version}",
        "context": project["context"],
        "dockerfile": project["dockerfile"],
        "build_args": project.get("build_args") or {},
    }
    return entry


def parse_single(tag: str, config: dict[str, Any]) -> dict[str, Any]:
    pattern = re.compile(config["tag_pattern"])
    match = pattern.fullmatch(tag)
    if not match:
        raise ValueError(
            f"tag「{tag}」不符合规则 {{project}}-{{version}}，"
            "例如 appbackend-v061201、all-v061201 或 services-v061201"
        )

    project_key = match.group("project")
    version = match.group("version")
    project = config["projects"].get(project_key)
    if project is None:
        known = ", ".join(sorted(config["projects"]))
        raise ValueError(f"未知子项目「{project_key}」，已配置: {known}")

    return {
        "mode": "single",
        "tag": tag,
        **project_entry(project_key, version, project),
    }


def _service_project_keys(config: dict[str, Any]) -> list[str]:
    groups = config.get("tag_groups") or {}
    keys = groups.get("services")
    if not keys:
        return list(DEFAULT_SERVICE_PROJECT_KEYS)
    return list(keys)


def _projects_for_keys(
    config: dict[str, Any],
    project_keys: list[str],
    version: str,
) -> list[dict[str, Any]]:
    projects_cfg = config["projects"]
    projects: list[dict[str, Any]] = []
    for project_key in project_keys:
        project = projects_cfg.get(project_key)
        if project is None:
            known = ", ".join(sorted(projects_cfg))
            raise ValueError(f"tag_groups.services 含未知子项目「{project_key}」，已配置: {known}")
        projects.append(project_entry(project_key, version, project))
    return projects


def parse_all(tag: str, config: dict[str, Any]) -> dict[str, Any]:
    match = ALL_TAG_PATTERN.fullmatch(tag)
    if not match:
        raise ValueError(f"tag「{tag}」不符合 all-vVERSION，例如 all-v061201")

    version = match.group("version")
    project_keys = sorted(config["projects"])
    return {
        "mode": "all",
        "tag": tag,
        "version": version,
        "projects": _projects_for_keys(config, project_keys, version),
    }


def parse_services(tag: str, config: dict[str, Any]) -> dict[str, Any]:
    match = SERVICES_TAG_PATTERN.fullmatch(tag)
    if not match:
        raise ValueError(f"tag「{tag}」不符合 services-vVERSION，例如 services-v061201")

    version = match.group("version")
    project_keys = _service_project_keys(config)
    return {
        "mode": "services",
        "tag": tag,
        "version": version,
        "projects": _projects_for_keys(config, project_keys, version),
    }


def parse_tag(tag: str) -> dict[str, Any]:
    normalized = normalize_tag(tag)
    config = load_config()
    if ALL_TAG_PATTERN.fullmatch(normalized):
        return parse_all(normalized, config)
    if SERVICES_TAG_PATTERN.fullmatch(normalized):
        return parse_services(normalized, config)
    return parse_single(normalized, config)


def build_matrix(parsed: dict[str, Any]) -> list[dict[str, Any]]:
    if parsed["mode"] in ("all", "services"):
        return parsed["projects"]
    return [
        {
            "project_key": parsed["project_key"],
            "version": parsed["version"],
            "image_name": parsed["image_name"],
            "image_ref": parsed["image_ref"],
            "context": parsed["context"],
            "dockerfile": parsed["dockerfile"],
            "build_args": parsed.get("build_args") or {},
        }
    ]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse_tag.py <git-tag>", file=sys.stderr)
        return 2

    try:
        parsed = parse_tag(sys.argv[1])
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(json.dumps(parsed, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
