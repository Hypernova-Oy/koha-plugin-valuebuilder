#!/bin/bash
# Copyright 2026 Hypernova Oy
#
# Reproducible release build for koha-plugin-valuebuilder.
#
# Versioning: the release version is the git tag pointing at HEAD (e.g.
# v0.1.9). If HEAD is not tagged, the patch segment of the newest reachable
# tag is incremented and a new tag is created on HEAD. If the repository has
# no tags at all, the version in the .pm metadata is used as a fallback and no
# tag is created.
#
# Reproducibility: the .kpz is a deterministic zip - entries are written in
# sorted order and every entry timestamp is taken from the HEAD commit date
# (UTC). The plugin metadata $VERSION and $DATE_UPDATED are rewritten in the
# dist copy only, from the tag and the commit date, so building the same
# commit on any machine yields byte-identical artefacts.
#
# Artifacts:
#   <name>-<version>.kpz            the installable plugin package
#   <name>-<version>.kpz.sha256     SHA-256 checksum (sha256sum format)
#   <name>-<version>.kpz.sha512     SHA-512 checksum (sha512sum format)
#   <name>-<version>.kpz.buildinfo  provenance manifest (version, commit, hashes)

cd "$(dirname "$0")"

BASEPATH='Koha/Plugin/Fi/Hypernova/ValueBuilder'
PM_FILE="$BASEPATH.pm"
NAME='koha-plugin-valuebuilder'

# --- version ---------------------------------------------------------------
VERSION=$(git log -1 --pretty=oneline --decorate | grep -Eo 'tag: v[0-9.]+' | sed -e 's/tag: v//' | head -n 1)
if [ -z "$VERSION" ]; then
    LATEST=$(git log --pretty=oneline --decorate | grep -Eo 'tag: v[0-9.]+' | sed -e 's/tag: v//' | head -n 1)
    if [ -n "$LATEST" ]; then
        VERSION=$(echo "$LATEST" | perl -pe 's/^((\d+\.)*)(\d+)(.*)$/$1.($3+1).$4/e')
        git tag "v$VERSION"
        echo "Created new version tag v$VERSION"
    else
        VERSION=$(grep -oP '^our\s+\$VERSION\s*=\s*"\K[^"]+' "$PM_FILE" | head -n 1)
        echo "No tags found; using .pm version $VERSION (no tag created)"
    fi
fi

# --- reproducible inputs ----------------------------------------------------
COMMIT=$(git rev-parse HEAD)
COMMIT_EPOCH=$(git log -1 --format=%ct)
DATE_UPDATED=$(date -u -d "@$COMMIT_EPOCH" +%Y-%m-%d)

RELEASE_FILE="${NAME}-${VERSION}.kpz"

echo "Building release package ${RELEASE_FILE}"
echo "  version      = ${VERSION}"
echo "  commit       = ${COMMIT}"
echo "  date_updated = ${DATE_UPDATED}"

# --- stage dist ------------------------------------------------------------
[ -e "$RELEASE_FILE" ] && rm -f "$RELEASE_FILE"
rm -rf dist
mkdir -p "dist/$BASEPATH"
cp -r "$BASEPATH"/* "dist/$BASEPATH/"
cp "$PM_FILE" "dist/$PM_FILE"

# Rewrite $VERSION and $DATE_UPDATED in the dist copy only. The plugin keeps
# its release version in `our $VERSION = "..."` / `our $DATE_UPDATED = "..."`
# (with a #PLACEHOLDER marker in the sources), so rewrite those declarations.
NEW_VERSION="$VERSION" perl -i -pe \
    's{^(our[ \t]+\$VERSION[ \t]*=[ \t]*)"[^"]*";?[ \t]*(?:#PLACEHOLDER)?[ \t]*$}{${1}"$ENV{NEW_VERSION}";}' \
    "dist/$PM_FILE"
NEW_DATE_UPDATED="$DATE_UPDATED" perl -i -pe \
    's{^(our[ \t]+\$DATE_UPDATED[ \t]*=[ \t]*)"[^"]*";?[ \t]*(?:#PLACEHOLDER)?[ \t]*$}{${1}"$ENV{NEW_DATE_UPDATED}";}' \
    "dist/$PM_FILE"

# --- build reproducible zip + checksums + provenance ------------------------
python3 - "$RELEASE_FILE" "$COMMIT_EPOCH" "$VERSION" "$COMMIT" "$DATE_UPDATED" "$NAME" <<'PYEOF'
import hashlib
import os
import sys
import time
import zipfile

out_name = sys.argv[1]
epoch = int(sys.argv[2])
version = sys.argv[3]
commit = sys.argv[4]
date_updated = sys.argv[5]
name = sys.argv[6]

# Entry timestamps come from the HEAD commit date (UTC) so the archive is
# byte-for-byte reproducible regardless of when or where it is built.
dt = time.gmtime(epoch)[:6]
commit_iso = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(epoch))

entries = []
with zipfile.ZipFile(out_name, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk('dist/Koha'):
        dirs.sort()
        for fname in sorted(files):
            path = os.path.join(root, fname)
            arcname = os.path.relpath(path, 'dist')  # 'Koha/...'
            info = zipfile.ZipInfo(arcname, date_time=dt)
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(path, 'rb') as fh:
                data = fh.read()
            z.writestr(info, data)
            entries.append(arcname)


def digest_file(path, algo):
    h = hashlib.new(algo)
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


sha256 = digest_file(out_name, 'sha256')
sha512 = digest_file(out_name, 'sha512')
size = os.path.getsize(out_name)

with open(out_name + '.sha256', 'w') as fh:
    fh.write(f"{sha256}  {out_name}\n")
with open(out_name + '.sha512', 'w') as fh:
    fh.write(f"{sha512}  {out_name}\n")

with open(out_name + '.buildinfo', 'w') as fh:
    fh.write(f"name: {name}\n")
    fh.write(f"version: {version}\n")
    fh.write(f"date_updated: {date_updated}\n")
    fh.write(f"git_commit: {commit}\n")
    fh.write(f"git_commit_date: {commit_iso}\n")
    fh.write(f"file: {out_name}\n")
    fh.write(f"size: {size}\n")
    fh.write(f"sha256: {sha256}\n")
    fh.write(f"sha512: {sha512}\n")
    fh.write(f"entries: {len(entries)}\n")

print(f"wrote {out_name} ({size} bytes, {len(entries)} entries)")
print(f"  sha256: {sha256}")
print(f"  sha512: {sha512}")
PYEOF

rm -rf dist
echo "Done."
