#!/usr/bin/env bash
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail
if [[ "$#" -ne 6 ]]; then
    echo "Usage: $0 <qtac.node> <qt-prefix> <qtac-runtime-lib-dir> <package-dir> <source-commit> <qt-version>" >&2
    exit 2
fi
addon="$(realpath "$1")"
qt_prefix="$(realpath "$2")"
qtac_lib="$(realpath "$3")"
package_dir="$4"
source_commit="$5"
qt_version="$6"
[[ -f "$addon" ]] || { echo "Addon not found: $addon" >&2; exit 1; }
[[ -d "$qt_prefix/lib" ]] || { echo "Qt lib directory missing: $qt_prefix/lib" >&2; exit 1; }
[[ -d "$qtac_lib" ]] || { echo "QTAC lib directory missing: $qtac_lib" >&2; exit 1; }
[[ ! -e "$package_dir" ]] || { echo "Package directory already exists: $package_dir" >&2; exit 1; }
command -v patchelf >/dev/null || { echo "patchelf is required" >&2; exit 1; }
mkdir -p "$package_dir/lib"
cp "$addon" "$package_dir/qtac.node"
patchelf --set-rpath '$ORIGIN/lib' "$package_dir/qtac.node"
ldd_output="$(LD_LIBRARY_PATH="$qt_prefix/lib:$qtac_lib" ldd "$package_dir/qtac.node")"
if grep -q 'not found' <<<"$ldd_output"; then
    echo "Unresolved runtime dependencies:" >&2
    grep 'not found' <<<"$ldd_output" >&2
    exit 1
fi
declare -A copied=()
declare -A external=()
while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    dependency_name="$(basename "$dependency")"
    resolved_dependency="$(realpath "$dependency")"
    case "$resolved_dependency" in
        "$qt_prefix"/*|"$qtac_lib"/*)
            name="$dependency_name"
            destination="$package_dir/lib/$name"
            if [[ -e "$destination" ]] && ! cmp -s "$resolved_dependency" "$destination"; then
                echo "Conflicting dependency filename: $name" >&2
                exit 1
            fi
            [[ -e "$destination" ]] || cp -L "$dependency" "$destination"
            copied["$name"]=1
            ;;
        /lib/*|/usr/lib/*) external["$(basename "$resolved_dependency")"]=1 ;;
        *) echo "Dependency outside known runtime/system roots: $resolved_dependency" >&2; exit 1 ;;
    esac
done < <(awk '/=> \// { print $3 } /^[[:space:]]*\// { print $1 }' <<<"$ldd_output" | sort -u)
shopt -s nullglob
libraries=("$package_dir"/lib/*)
if ! compgen -G "$package_dir/lib/*" >/dev/null; then
    echo "No non-system runtime libraries were staged" >&2
    exit 1
fi
for library in "${libraries[@]}"; do
    patchelf --set-rpath '$ORIGIN' "$library"
done
printf '%s\n' "${!copied[@]}" | sort > "$package_dir/.bundled-names"
printf '%s\n' "${!external[@]}" | sort > "$package_dir/.external-names"
python3 - "$package_dir/runtime-manifest.json" "$source_commit" "$qt_version" "$package_dir/.bundled-names" "$package_dir/.external-names" <<'PY'
import json
import sys
from pathlib import Path

manifest_path, commit, qt_version, bundled_path, external_path = sys.argv[1:]
read_names = lambda name: [line for line in Path(name).read_text().splitlines() if line]
manifest = {
    "platform": "linux",
    "architecture": "x64",
    "qtVersion": qt_version,
    "nodeApi": 8,
    "sourceCommit": commit,
    "minimumOs": "Ubuntu 22.04 (glibc baseline)",
    "bundledLibraries": read_names(bundled_path),
    "externalSystemLibraries": read_names(external_path),
}
Path(manifest_path).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
Path(bundled_path).unlink()
Path(external_path).unlink()
PY
echo "Minimal Linux addon package staged at: $package_dir"
