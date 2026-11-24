#!/usr/bin/env bash
# drive-fetch.sh <folderId> <outDir> : recursively download a public Google Drive folder
set -u
fetch() {
  local id="$1" out="$2"
  mkdir -p "$out"
  local html; html=$(curl -sL "https://drive.google.com/embeddedfolderview?id=$id")
  # pairs of (url, title)
  echo "$html" | grep -oE 'href="https://drive.google.com/(file/d|drive/folders)/[^"]+"|flip-entry-title">[^<]+' | paste - - | while IFS=$'\t' read -r href title; do
    title="${title#flip-entry-title\">}"
    title=$(printf '%s' "$title" | sed 's/&amp;/\&/g;s/&#39;/'"'"'/g')
    if [[ "$href" == *drive/folders/* ]]; then
      sub=$(echo "$href" | sed -E 's#.*folders/([^"?]+).*#\1#')
      fetch "$sub" "$out/$title"
    else
      fid=$(echo "$href" | sed -E 's#.*file/d/([^/"]+).*#\1#')
      if [ ! -s "$out/$title" ]; then
        curl -sL -o "$out/$title" "https://drive.usercontent.google.com/download?id=$fid&export=download&confirm=t"
        echo "got $out/$title ($(stat -c%s "$out/$title") B)"
      fi
    fi
  done
}
fetch "$1" "$2"
