#!/bin/bash
# Re-imports OW2 ASM sources into this bundle under EclipseLink's repackaged namespace
# (org.objectweb.asm -> org.eclipse.persistence.internal.libraries.asm).
#
# Usage: ./update-asm.sh <asm-version>     e.g. ./update-asm.sh 9.8
#
# CUBA 2.6.2.cuba27: replaces the bundled ASM 5.0.1 (class files up to Java 8 only)
# so that EclipseLink can weave and read metadata of Java 21 (v65) entity classes.
set -euo pipefail

VERSION="${1:?asm version required}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/src"
TARGET_PKG_DIR="$SRC/org/eclipse/persistence/internal/libraries/asm"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

MODULES="asm asm-tree asm-analysis asm-commons asm-util"
for m in $MODULES; do
    url="https://repo1.maven.org/maven2/org/ow2/asm/$m/$VERSION/$m-$VERSION-sources.jar"
    echo "Downloading $url"
    curl -sSfL -o "$WORK/$m.jar" "$url"
    (cd "$WORK" && mkdir -p "$m" && cd "$m" && unzip -q "../$m.jar")
done

rm -rf "$TARGET_PKG_DIR"
mkdir -p "$TARGET_PKG_DIR"
for m in $MODULES; do
    if [ -d "$WORK/$m/org/objectweb/asm" ]; then
        cp -r "$WORK/$m/org/objectweb/asm/." "$TARGET_PKG_DIR/"
    fi
done
# package-info/module-info and non-Java resources are not needed in the bundle
find "$TARGET_PKG_DIR" -name 'module-info.java' -delete
find "$TARGET_PKG_DIR" -type f ! -name '*.java' -delete

find "$TARGET_PKG_DIR" -name '*.java' -print0 | xargs -0 sed -i \
    -e 's/org\.objectweb\.asm/org.eclipse.persistence.internal.libraries.asm/g' \
    -e 's#org/objectweb/asm#org/eclipse/persistence/internal/libraries/asm#g' \
    -e 's/@Deprecated(forRemoval = false)/@Deprecated/g'
# ^ the bundle is compiled by the JDK 8 Tycho build; @Deprecated attributes are Java 9+

echo "$VERSION" > "$HERE/ASM_VERSION"
echo "Imported ASM $VERSION: $(find "$TARGET_PKG_DIR" -name '*.java' | wc -l) source files"
