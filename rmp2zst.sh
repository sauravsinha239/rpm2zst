sudo tee /usr/local/bin/rpm2zst > /dev/null << 'EOF'
#!/usr/bin/env bash
set -e

if [[ $EUID -eq 0 ]]; then
    echo "Error: Do not run as root (makepkg forbids root)."
    exit 1
fi

if [[ -z "$1" || ! -f "$1" ]]; then
    echo "Usage: rpm2zst <path-to-file.rpm>"
    exit 1
fi

RPM_PATH="$(realpath "$1")"
RPM_FILE="$(basename "$RPM_PATH")"
OUT_DIR="$(pwd)"

# Parse name and version from filename (fallback to sanitized filename)
BASE="${RPM_FILE%.rpm}"
BASE="${BASE%.x86_64}"
BASE="${BASE%.noarch}"
PKGNAME="$(echo "$BASE" | sed -E 's/-[0-9]+.*//' | tr '[:upper:]_' '[:lower:]-')"
PKGVER="$(echo "$BASE" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)"
[[ -z "$PKGNAME" ]] && PKGNAME="converted-rpm"
[[ -z "$PKGVER" ]] && PKGVER="1.0.0"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cp "$RPM_PATH" "$BUILD_DIR/"
cd "$BUILD_DIR"

cat << PKGEOF > PKGBUILD
pkgname=${PKGNAME}
pkgver=${PKGVER}
pkgrel=1
pkgdesc="Converted from ${RPM_FILE}"
arch=('x86_64')
license=('custom')
depends=()
source=("${RPM_FILE}")
sha256sums=('SKIP')

package() {
    cp -a "\$srcdir"/{usr,opt,etc,var} "\$pkgdir/" 2>/dev/null || true
}
PKGEOF

makepkg -f

ZST_FILE="$(ls ./*.pkg.tar.zst | head -n1)"
cp "$ZST_FILE" "$OUT_DIR/"
FINAL_ZST="$OUT_DIR/$(basename "$ZST_FILE")"

echo ""
echo "Built: $FINAL_ZST"
read -rp "Install now with pacman? [y/N]: " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo pacman -U "$FINAL_ZST"
fi
EOF

sudo chmod +x /usr/local/bin/rpm2zst
