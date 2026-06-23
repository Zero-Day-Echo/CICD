#!/usr/bin/env python3
"""输出 GitHub Actions matrix JSON（单项目 1 项，all-v* / services-v* 展开子项目列表）。"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# 与 parse_tag.py 同目录，便于 Actions / 本地直接调用
sys.path.insert(0, str(Path(__file__).resolve().parent))

from parse_tag import build_matrix, parse_tag  # noqa: E402


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse_release_matrix.py <git-tag>", file=sys.stderr)
        return 2

    try:
        parsed = parse_tag(sys.argv[1])
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(json.dumps(build_matrix(parsed), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
