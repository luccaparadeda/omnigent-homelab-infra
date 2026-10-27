#!/usr/bin/env python3
"""Apply or revert the pinned Omnigent 0.19.1 macOS Codex workaround.

Omnigent 0.19.1 links Codex's shared ``memories_1.sqlite`` into every private
CODEX_HOME. Codex 0.154.0 cannot initialize that external SQLite state through
Omnibox's macOS Seatbelt profile. It also needs two read-only preference
domains and a ``system-socket`` operation when unrestricted networking is
enabled. These narrow compatibility patches keep memory session-local and make
Codex configuration loading work without exposing the subscription token.

The patch is intentionally fail-closed: package version, complete source hash,
and the exact source line must all match. Upgrading or reinstalling Omnigent
removes the workaround; re-evaluate upstream before applying it again.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import os
import shutil
import stat
import sys
import tempfile
from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path


PACKAGE_VERSION = "0.19.1"
BACKUP_SUFFIX = ".omnigent-homelab-0.19.1.bak"


@dataclass(frozen=True)
class PatchSpec:
    module: str
    original_sha256: str
    patched_sha256: str
    replacements: tuple[tuple[str, str], ...]


CODEX_ORIGINAL_LINE = (
    '_CODEX_HOME_SYMLINK_FILES = ("auth.json", ".credentials.json", '
    '"memories_1.sqlite")'
)
CODEX_PATCHED_LINE = '_CODEX_HOME_SYMLINK_FILES = ("auth.json", ".credentials.json")'
SEATBELT_ORIGINAL_PREFERENCES = (
    '            "(allow sysctl-read)",\n'
    '            "(allow file-ioctl)",'
)
SEATBELT_PATCHED_PREFERENCES = (
    '            "(allow sysctl-read)",\n'
    '            \'(allow user-preference-read (preference-domain '
    '"com.openai.codex"))\',\n'
    '            \'(allow user-preference-read (preference-domain '
    '"kCFPreferencesAnyApplication"))\',\n'
    '            "(allow file-ioctl)",'
)
SEATBELT_ORIGINAL_NETWORK = (
    '        lines.append(";; allow_network=true — host network shared")\n'
    '        lines.append("(allow network*)")'
)
SEATBELT_PATCHED_NETWORK = (
    '        lines.append(";; allow_network=true — host network shared")\n'
    '        lines.append("(allow system-socket)")\n'
    '        lines.append("(allow network*)")'
)
PATCHES = (
    PatchSpec(
        module="omnigent.inner.codex_executor",
        original_sha256="8d5a4b16e67256d2eb546883edc9039602d04e492f3ff919c1c69aa240695f04",
        patched_sha256="4fa4bbc61939f73bdbdce5f1968f70db75a79d810c8aee777e25c38090ad3a87",
        replacements=((CODEX_ORIGINAL_LINE, CODEX_PATCHED_LINE),),
    ),
    PatchSpec(
        module="omnigent.inner.seatbelt_sandbox",
        original_sha256="51b98cda8847d27e039136555fdf00e9e21d49853f11d59201fad4a520e82ff0",
        patched_sha256="c9ff89f2659a555c4f899f91e05f639abc7df46609735deeace4d3c055f063da",
        replacements=(
            (SEATBELT_ORIGINAL_PREFERENCES, SEATBELT_PATCHED_PREFERENCES),
            (SEATBELT_ORIGINAL_NETWORK, SEATBELT_PATCHED_NETWORK),
        ),
    ),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ensure_omnigent_interpreter() -> None:
    """Re-exec through the isolated uv-tool interpreter when necessary."""
    try:
        version("omnigent")
        return
    except PackageNotFoundError:
        pass
    launcher_name = shutil.which("omni")
    if launcher_name is None:
        raise RuntimeError("cannot find the Omnigent 'omni' launcher on PATH")
    first_line = Path(launcher_name).read_text().splitlines()[0]
    if not first_line.startswith("#!"):
        raise RuntimeError(f"Omnigent launcher has no interpreter: {launcher_name}")
    # Do not resolve a virtual-environment interpreter symlink: Python uses the
    # invoked path to select that environment's site-packages.
    interpreter = Path(first_line[2:])
    if (
        not interpreter.is_absolute()
        or not interpreter.is_file()
        or not os.access(interpreter, os.X_OK)
        or not interpreter.name.startswith("python")
    ):
        raise RuntimeError(f"refusing unexpected Omnigent interpreter: {interpreter}")
    if interpreter.absolute() == Path(sys.executable).absolute():
        raise RuntimeError("Omnigent package is unavailable to its launcher interpreter")
    os.execv(
        interpreter,
        [str(interpreter), str(Path(__file__).resolve()), *sys.argv[1:]],
    )


def package_sources() -> tuple[tuple[PatchSpec, Path], ...]:
    try:
        installed_version = version("omnigent")
    except PackageNotFoundError as exc:
        raise RuntimeError("Omnigent is not installed in this Python environment") from exc
    if installed_version != PACKAGE_VERSION:
        raise RuntimeError(
            f"expected Omnigent {PACKAGE_VERSION}, found {installed_version}; "
            "do not apply this version-scoped workaround"
        )
    sources: list[tuple[PatchSpec, Path]] = []
    for patch in PATCHES:
        module_spec = importlib.util.find_spec(patch.module)
        if module_spec is None or module_spec.origin is None:
            raise RuntimeError(f"cannot locate {patch.module}")
        sources.append((patch, Path(module_spec.origin).resolve()))
    return tuple(sources)


def replace_atomically(
    path: Path, replacements: tuple[tuple[str, str], ...]
) -> None:
    source = path.read_text()
    for old, _new in replacements:
        if source.count(old) != 1:
            raise RuntimeError("expected source fragment does not occur exactly once")
    updated = source
    for old, new in replacements:
        updated = updated.replace(old, new)
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "w") as destination:
            destination.write(updated)
            destination.flush()
            os.fsync(destination.fileno())
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def status(patch: PatchSpec, path: Path) -> str:
    current_hash = sha256(path)
    if current_hash == patch.original_sha256:
        return "original"
    if current_hash == patch.patched_sha256:
        return "patched"
    return f"unknown ({current_hash})"


def preflight(action: str, sources: tuple[tuple[PatchSpec, Path], ...]) -> None:
    """Validate every source and backup before changing any package file."""
    for patch, path in sources:
        current = status(patch, path)
        if current not in ("original", "patched"):
            raise RuntimeError(f"refusing {action} for unexpected source: {current}")
        backup = path.with_name(path.name + BACKUP_SUFFIX)
        if action == "apply":
            if backup.exists() and sha256(backup) != patch.original_sha256:
                raise RuntimeError(f"refusing to replace unexpected backup: {backup}")
            if current == "patched" and not backup.exists():
                raise RuntimeError(f"patched source has no reviewed backup: {backup}")
        elif current == "patched":
            if not backup.exists() or sha256(backup) != patch.original_sha256:
                raise RuntimeError(f"reviewed original backup is missing: {backup}")


def apply(patch: PatchSpec, path: Path) -> None:
    current = status(patch, path)
    if current == "patched":
        print(f"already patched: {path}")
        return
    if current != "original":
        raise RuntimeError(f"refusing to patch unexpected source: {current}")
    backup = path.with_name(path.name + BACKUP_SUFFIX)
    if backup.exists() and sha256(backup) != patch.original_sha256:
        raise RuntimeError(f"refusing to replace unexpected backup: {backup}")
    if not backup.exists():
        shutil.copy2(path, backup)
    replace_atomically(path, patch.replacements)
    if sha256(path) != patch.patched_sha256:
        raise RuntimeError("patched file hash does not match the reviewed result")
    print(f"patched: {path}")
    print(f"backup: {backup}")


def revert(patch: PatchSpec, path: Path) -> None:
    current = status(patch, path)
    if current == "original":
        print(f"already original: {path}")
        return
    if current != "patched":
        raise RuntimeError(f"refusing to revert unexpected source: {current}")
    backup = path.with_name(path.name + BACKUP_SUFFIX)
    if not backup.exists() or sha256(backup) != patch.original_sha256:
        raise RuntimeError(f"reviewed original backup is missing: {backup}")
    reverse = tuple((new, old) for old, new in patch.replacements)
    replace_atomically(path, reverse)
    if sha256(path) != patch.original_sha256:
        raise RuntimeError("restored file hash does not match Omnigent 0.19.1")
    print(f"reverted: {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "apply", "revert"))
    args = parser.parse_args()
    try:
        ensure_omnigent_interpreter()
        sources = package_sources()
        if args.action != "check":
            preflight(args.action, sources)
        for patch, path in sources:
            if args.action == "check":
                print(f"{status(patch, path)}: {path}")
            elif args.action == "apply":
                apply(patch, path)
            else:
                revert(patch, path)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
