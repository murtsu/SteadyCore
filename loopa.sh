#!/usr/bin/env bash
# gorloop.sh - viker slutet av en låt över början så att den loopar sömlöst.
#
#   ./gorloop.sh bed.flac            # 12 sekunders korsfade
#   ./gorloop.sh bed.flac 18         # egen längd
#
# Ut kommer loop.flac, T sekunder kortare än originalet, och lektion.flac
# med tjugo varv. Originalet rörs aldrig.

set -euo pipefail
export LC_ALL=C          # svensk locale ger komma där bc vill ha punkt

IN="${1:-}"
T="${2:-12}"
VARV="${3:-20}"

[ -n "$IN" ] || { echo "Ange en infil: $0 <fil.flac> [korsfade] [varv]" >&2; exit 1; }
[ -f "$IN" ] || { echo "Hittar inte $IN" >&2; exit 1; }
command -v sox >/dev/null || { echo "sox saknas: sudo apt install sox libsox-fmt-all" >&2; exit 1; }
command -v bc  >/dev/null || { echo "bc saknas: sudo apt install bc" >&2; exit 1; }

L=$(soxi -D "$IN")
if (( $(echo "$T > $L / 3" | bc -l) )); then
    echo "Korsfaden ($T s) är för lång för en fil på $L s. Ta max $(echo "$L / 3" | bc) s." >&2
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

M=$(echo "$L - $T"  | bc)     # där svansen börjar
B=$(echo "$M - $T"  | bc)     # mittendelens längd

sox "$IN" "$TMP/head.wav" trim 0  "$T"
sox "$IN" "$TMP/tail.wav" trim "$M" "$T"
sox "$IN" "$TMP/body.wav" trim "$T" "$B"

sox "$TMP/head.wav" "$TMP/head_in.wav"  fade t "$T"
sox "$TMP/tail.wav" "$TMP/tail_out.wav" fade 0 "$T" "$T"

# -G håller summan under 0 dBFS. Två delar av samma låt ovanpå varandra
# kan annars klippa.
sox -G -m "$TMP/head_in.wav" "$TMP/tail_out.wav" "$TMP/xfade.wav"
sox "$TMP/xfade.wav" "$TMP/body.wav" loop.flac

sox loop.flac lektion.flac repeat $(( VARV - 1 ))

printf '\n%s: %s s\nloop.flac: %s s\nlektion.flac: %s s (%d varv)\n\n' \
    "$IN" "$L" "$(soxi -D loop.flac)" "$(soxi -D lektion.flac)" "$VARV"
echo "Lyssna på skarven: sox loop.flac -d repeat 2"

