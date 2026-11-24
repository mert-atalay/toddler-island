#!/usr/bin/env bash
# itch-fetch.sh <user> <game> <outDir> [list]
# Downloads every free upload on an itch.io page (or just lists them with "list").
set -u
U="$1"; G="$2"; OUT="$3"; MODE="${4:-get}"
J=$(mktemp); TMP=$(mktemp)
tok() { grep -oE 'name="csrf_token" value="[^"]+"' | head -1 | sed -E 's/.*value="([^"]+)"/\1/'; }
jurl() { grep -oE '"url":"[^"]+"' | cut -d'"' -f4 | sed 's#[\\]##g'; }

csrf=$(curl -sL -c "$J" -b "$J" "https://$U.itch.io/$G" | tok)
durl=$(curl -sL -c "$J" -b "$J" -X POST --data-urlencode "csrf_token=$csrf" "https://$U.itch.io/$G/download_url" | jurl)
key=$(echo "$durl" | sed -E 's#.*/download/([^/?]+).*#\1#')
curl -sL -c "$J" -b "$J" "$durl" -o "$TMP"
c2=$(tok < "$TMP"); [ -n "$c2" ] && csrf=$c2

mkdir -p "$OUT"
grep -oE 'data-upload_id="[0-9]+"' "$TMP" | grep -oE '[0-9]+' | while read -r id; do
  name=$(grep -oE "data-upload_id=\"$id\".{0,400}" "$TMP" | grep -oE 'class="name" title="[^"]+"|class="upload_name"[^>]*>[^<]*<[^>]*title="[^"]+"' | grep -oE 'title="[^"]+"' | head -1 | cut -d'"' -f2)
  [ -z "$name" ] && name=$(grep -oE "data-upload_id=\"$id\".{0,600}" "$TMP" | sed 's/<[^>]*>/\n/g' | grep -E '\.(zip|rar|7z|glb|gltf|fbx)$' | head -1)
  [ -z "$name" ] && name="upload-$id.zip"
  echo "upload $id  $name"
  if [ "$MODE" = get ] && [ ! -s "$OUT/$name" ]; then
    furl=$(curl -sL -c "$J" -b "$J" -X POST --data-urlencode "csrf_token=$csrf" "https://$U.itch.io/$G/file/$id?source=game_download" | jurl)
    curl -sL -o "$OUT/$name" "$furl"
    echo "  -> $(stat -c%s "$OUT/$name") bytes"
  fi
done
rm -f "$J" "$TMP"
