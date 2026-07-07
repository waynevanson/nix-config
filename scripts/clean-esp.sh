#!/usr/bin/env bash
set -euo pipefail

# Clean orphaned kernels/initrds from /boot (ESP).
# Default is dry-run; pass --execute to actually delete.

EXECUTE=0
REMOVE_GRUB=0

for arg in "$@"; do
  case "$arg" in
    --execute) EXECUTE=1 ;;
    --dry-run) EXECUTE=0 ;;
    --remove-grub) REMOVE_GRUB=1 ;;
    -h|--help)
      echo "Usage: $0 [--execute] [--dry-run] [--remove-grub]"
      echo "  --dry-run      show what would be deleted (default)"
      echo "  --execute      actually delete files"
      echo "  --remove-grub  also remove /boot/grub (dangerous if you use GRUB)"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

BOOT="/boot"
KERNELS_DIR="$BOOT/kernels"
NIXOS_EFI_DIR="$BOOT/EFI/nixos"
ENTRIES_DIR="$BOOT/loader/entries"
GRUB_DIR="$BOOT/grub"

# Collect file basenames referenced by current boot loader entries.
referenced_files=$(mktemp)
trap 'rm -f "$referenced_files"' EXIT

if [[ -d "$ENTRIES_DIR" ]]; then
  grep -RhE '^(linux|initrd|efi)' "$ENTRIES_DIR" 2>/dev/null | \
    sed -E 's/^(linux|initrd|efi)\s+//' | \
    xargs -n1 basename 2>/dev/null | \
    sort -u > "$referenced_files" || true
fi

# Also mark the current generation's kernel/initrd as referenced.
current_kernel=$(readlink /run/current-system/kernel || true)
if [[ -n "$current_kernel" ]]; then
  basename "$current_kernel" >> "$referenced_files"
  # Initrd usually shares the store path basename plus -initrd.
  basename "${current_kernel%-kernel}"-initrd >> "$referenced_files" 2>/dev/null || true
fi

sort -u "$referenced_files" -o "$referenced_files"

# Files to keep: anything referenced by loader entries or current generation.
keep() {
  grep -qxF "$1" "$referenced_files"
}

remove_file() {
  local file="$1"
  if [[ "$EXECUTE" -eq 1 ]]; then
    rm -f "$file"
    echo "  removed: $file"
  else
    echo "  would remove: $file"
  fi
}

freed=0

# Clean /boot/kernels
if [[ -d "$KERNELS_DIR" ]]; then
  echo "Scanning $KERNELS_DIR ..."
  while IFS= read -r -d '' file; do
    name=$(basename "$file")
    if ! keep "$name"; then
      size=$(stat -c%s "$file")
      remove_file "$file"
      freed=$((freed + size))
    fi
  done < <(find "$KERNELS_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
fi

# Clean /boot/EFI/nixos
if [[ -d "$NIXOS_EFI_DIR" ]]; then
  echo "Scanning $NIXOS_EFI_DIR ..."
  while IFS= read -r -d '' file; do
    name=$(basename "$file")
    if ! keep "$name"; then
      size=$(stat -c%s "$file")
      remove_file "$file"
      freed=$((freed + size))
    fi
  done < <(find "$NIXOS_EFI_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
fi

# Optionally remove /boot/grub
if [[ "$REMOVE_GRUB" -eq 1 && -d "$GRUB_DIR" ]]; then
  if [[ "$EXECUTE" -eq 1 ]]; then
    size=$(du -sb "$GRUB_DIR" | cut -f1)
    rm -rf "$GRUB_DIR"
    freed=$((freed + size))
    echo "  removed: $GRUB_DIR"
  else
    echo "  would remove: $GRUB_DIR"
  fi
fi

if [[ "$EXECUTE" -eq 0 ]]; then
  echo ""
  echo "Dry-run complete. Pass --execute to delete the listed files."
fi

echo ""
echo "Approximate space freed: $(numfmt --to=iec "$freed")"
