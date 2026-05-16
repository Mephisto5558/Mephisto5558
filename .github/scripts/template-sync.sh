#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/$BASE_REPO/$BASE_BRANCH/templates"
CHANGELOG=""

while read -r pair; do
  CLEAN=$(echo "$pair" | xargs)
  if [[ -z "$CLEAN" || "$CLEAN" != *:* || "$CLEAN" == \#* || "$CLEAN" == //* ]]; then
    continue
  fi

  RAW_SRC="${CLEAN%%:*}"
  RAW_DEST="${CLEAN#*:}"
  SRC=$(echo "$RAW_SRC" | xargs)
  DEST=$(echo "$RAW_DEST" | xargs)

  echo "Processing $SRC -> $DEST"
  mkdir -p "$(dirname "$DEST")"

  if ! curl -sSf "$BASE_URL/$SRC" -o "$DEST.tmp"; then
    echo "Error: Could not fetch $SRC"
    exit 1
  fi

  if [ -f "$DEST" ]; then
    if grep -q "$START_MARKER" "$DEST" && grep -q "$END_MARKER" "$DEST"; then
      echo "Preserving custom block from $DEST"
      awk "/$START_MARKER/,/$END_MARKER/" "$DEST" > custom_block.txt
      
      if grep -q "$START_MARKER" "$DEST.tmp" && grep -q "$END_MARKER" "$DEST.tmp"; then
        # If marker is in template file
        awk -v start="$START_MARKER" -v end="$END_MARKER" '
          index($0, start) { system("cat custom_block.txt"); skip = 1; next }
          index($0, end)   { skip = 0; next }
          !skip            { print }
        ' "$DEST.tmp" > "$DEST.new"
      else
        ANCHOR_LINE=$(grep -B 1 "$START_MARKER" "$DEST" | head -n 1)
        if [ -n "$ANCHOR_LINE" ] && grep -qF "$ANCHOR_LINE" "$DEST.tmp"; then
          # If marker is not in template file but we find an anchor
          awk -v anchor="$ANCHOR_LINE" '
            index($0, anchor) {
              print
              system("cat custom_block.txt")
              next
            }
            { print }
          ' "$DEST.tmp" > "$DEST.new"
        else
          # Fallback: append to end
          cp "$DEST.tmp" "$DEST.new"
          echo "" >> "$DEST.new"
          cat custom_block.txt >> "$DEST.new"
        fi
      fi
      
      mv "$DEST.new" "$DEST.tmp"
      rm -f custom_block.txt
    fi
  fi

  mv "$DEST.tmp" "$DEST"
  git add -N "$DEST"

  if ! git diff --quiet "$DEST"; then
    echo "Changes detected for $DEST"
    MSG=$(echo "$COMMIT_MSG_TEMPLATE" | awk -v s="$SRC" -v d="$DEST" '{gsub(/{src}/,s); gsub(/{dest}/,d)}1')
    CHANGELOG="${CHANGELOG}- ${MSG}"$'\n'
  fi
done <<< "$MAPPINGS"

{
  echo "CHANGELOG<<EOF"
  echo "$CHANGELOG"
  echo "EOF"
} >> "$GITHUB_ENV"