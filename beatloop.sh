#!/usr/bin/env bash
# beatloop.sh - loopar ett spår med puls på hel takt, utan korsfade.
#
# gorloop.sh korsfadar tolv sekunder. Det fungerar för drone och blir en
# flam så fort det finns en trumma, eftersom två taktarter då ligger
# ovanpå varandra. Den här skarvar i stället rakt av på en etta.
#
#   ./beatloop.sh spar.flac 80              # 80 BPM, 4/4, 45 min ut
#   ./beatloop.sh spar.flac --bpm 80        # samma sak
#   ./beatloop.sh spar.flac 80 --min 71     # 71 minuter ut
#   ./beatloop.sh spar.flac 80 --offset 0.35
#   ./beatloop.sh spar.flac 96 --end 52     # strunta i allt efter 52 s
#   ./beatloop.sh spar.flac 96 --end auto   # hitta uttoningen sjalv
#   ./beatloop.sh spar.flac 96 --offset auto # hoppa fram till forsta slaget
#   ./beatloop.sh spar.flac --slag           # visa var de forsta slagen ligger
#   ./beatloop.sh spar.flac --profil        # visa var uttoningen börjar
#   ./beatloop.sh spar.flac --detect        # gissa tempot först
#
# Ut kommer loop.flac (hel takt, skarvbar) och lang.flac (upprepad).

set -euo pipefail
export LC_ALL=C          # svensk locale ger komma där bc vill ha punkt

IN=""; BPM=""; BEATS=4; OFFSET=0; TARGET_MIN=45; DETECT=0; FADE_MS=3
END=""; PROFILE=0; BEATS_LIST=0

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --detect)  DETECT=1; shift ;;
        --bpm)     BPM="$2"; shift 2 ;;
        --beats)   BEATS="$2"; shift 2 ;;
        --offset)  OFFSET="$2"; shift 2 ;;
        --end)     END="$2"; shift 2 ;;
        --profil)  PROFILE=1; shift ;;
        --slag)    BEATS_LIST=1; shift ;;
        --min)     TARGET_MIN="$2"; shift 2 ;;
        --fade)    FADE_MS="$2"; shift 2 ;;
        -h|--help) usage ;;
        --*) echo "Okand flagga: $1" >&2; echo "Giltiga: --bpm --beats --offset --end --min --fade --profil --slag --detect" >&2; exit 1 ;;
        *) if [ -z "$IN" ]; then IN="$1"; elif [ -z "$BPM" ]; then BPM="$1"; fi; shift ;;
    esac
done

[ -n "$IN" ] || usage
[ -f "$IN" ] || { echo "Hittar inte $IN" >&2; exit 1; }
command -v sox >/dev/null || { echo "sox saknas: sudo apt install sox libsox-fmt-all" >&2; exit 1; }
command -v bc  >/dev/null || { echo "bc saknas: sudo apt install bc" >&2; exit 1; }

# ---------------------------------------------------------------- profil
if [ "$PROFILE" = 1 ]; then
    DUR=$(soxi -D "$IN")
    echo
    echo "Niva per sekund. Dar staplarna borjar krympa i slutet startar uttoningen."
    echo
    for t in $(seq 0 1 $(echo "$DUR/1" | bc)); do
        R=$(sox "$IN" -n trim "$t" 1 stat 2>&1 | awk '/RMS.*amplitude/{print $3}')
        [ -z "$R" ] && continue
        BARS=$(echo "$R * 120 / 1" | bc)
        printf '%4s s  %-6.4f ' "$t" "$R"
        for i in $(seq 1 "${BARS:-0}"); do printf '#'; done
        printf '\n'
    done
    echo
    exit 0
fi

# ---------------------------------------------------------------- tempo
detect_bpm() {
    if command -v aubiotempo >/dev/null; then
        aubiotempo "$1" 2>/dev/null | head -1 | awk '{print $1}'
    elif command -v bpm >/dev/null; then
        sox "$1" -t raw -r 44100 -e float -c 1 - 2>/dev/null | bpm -f "%f"
    else
        echo ""
    fi
}

if [ "$BEATS_LIST" != 1 ] && { [ "$DETECT" = 1 ] || [ -z "$BPM" ]; }; then
    GUESS=$(detect_bpm "$IN" || true)
    if [ -n "$GUESS" ]; then
        printf 'Uppmätt tempo: %s BPM\n' "$GUESS"
    else
        echo "Ingen tempomätare installerad. sudo apt install aubio-tools" >&2
    fi
    [ "$DETECT" = 1 ] && exit 0
    [ -n "$GUESS" ] && BPM="$GUESS"
fi

[ -n "$BPM" ] || [ "$BEATS_LIST" = 1 ] || { echo "Ange BPM, det du bad ACE Step om." >&2; exit 1; }

# ------------------------------------------------------- hitta slutet
if [ "$END" = "auto" ]; then
    DUR=$(soxi -D "$IN")
    WIN=0.5
    LEVELS=$(for t in $(seq 0 "$WIN" "$(echo "$DUR - $WIN" | bc)"); do
        R=$(sox "$IN" -n trim "$t" "$WIN" stat 2>&1 | awk '/RMS.*amplitude/{print $3}')
        case "$R" in ''|*nan*) R=0 ;; esac
        echo "$t $R"
    done)
    MED=$(echo "$LEVELS" | awk '{print $2}' | sort -n | awk '{a[NR]=$1} END{print a[int(NR/2)+1]}')
    THR=$(echo "$MED * 0.6" | bc -l)
    END=$(echo "$LEVELS" | awk -v thr="$THR" -v w="$WIN" '$2>=thr{last=$1} END{print last+w}')
    printf 'Uttoning hittad: anvander materialet fram till %.2f s\n' "$END"
fi

# ------------------------------------------------- hitta forsta slaget
# Kicken ar det lagsta i sparet, sa allt annat lagpassas bort forst.
find_first_beat() {
    sox "$1" -r 2000 -c 1 -t dat - lowpass 90 2>/dev/null | awk '
      /^;/ {next}
      { n++; v=$2+0; e+=v*v
        if (n%50==0) { w++; win[w]=sqrt(e/50); if(win[w]>mx)mx=win[w]; e=0 } }
      END {
        thr=mx*0.45; c=0
        for (i=2;i<=w;i++)
          if (win[i]>thr && win[i-1]<=thr) { printf "%.3f\n",(i-1)*0.025; if(++c>=8) break }
      }'
}

if [ "$OFFSET" = "auto" ] || [ "$BEATS_LIST" = 1 ]; then
    HITS=$(find_first_beat "$IN")
    [ -n "$HITS" ] || { echo "Hittade ingen puls. Ange --offset manuellt." >&2; exit 1; }
    if [ "$BEATS_LIST" = 1 ]; then
        echo
        echo "Forsta atta slagen:"
        echo "$HITS" | sed 's/^/  /'
        echo
        echo "$HITS" | awk 'NR>1{printf "  avstand %.3f s\n",$1-p} {p=$1}'
        echo
        exit 0
    fi
    OFFSET=$(echo "$HITS" | head -1)
    printf 'Forsta slaget: %s s\n' "$OFFSET"
fi

# ---------------------------------------------------------------- matte
L=$(soxi -D "$IN")
BAR=$(echo "scale=9; 60 / $BPM * $BEATS" | bc)
if [ -n "$END" ]; then
    USABLE=$(echo "$END - $OFFSET" | bc)
else
    USABLE=$(echo "$L - $OFFSET" | bc)
fi
BARS=$(echo "($USABLE / $BAR) / 1" | bc)          # heltal, avrundat nedåt

[ "$BARS" -ge 1 ] || { echo "Filen rymmer inte ens en takt vid $BPM BPM." >&2; exit 1; }

LOOPLEN=$(echo "scale=9; $BARS * $BAR" | bc)
SPILL=$(echo "scale=3; $USABLE - $LOOPLEN" | bc)

printf '\n%s\n' "$IN"
printf '  langd        %.3f s\n' "$L"
printf '  tempo        %s BPM, %s slag per takt\n' "$BPM" "$BEATS"
printf '  en takt      %.4f s\n' "$BAR"
printf '  hela takter  %s  (%.3f s)\n' "$BARS" "$LOOPLEN"
printf '  kastas bort  %.3f s\n' "$SPILL"
[ -n "$END" ] && printf '  slutet kapat vid %s s (uttoning bortklippt)\n' "$END"
printf '\n' 

# Spillet ar alltid mellan noll och en takt och betyder ingenting i sig.
# Ar tempot fel hors det daremot direkt i skarven, sa lyssna hellre an att
# lita pa en siffra.

# ---------------------------------------------------------------- klipp
FADE=$(echo "scale=6; $FADE_MS / 1000" | bc)
sox -G "$IN" loop.flac trim "$OFFSET" "$LOOPLEN" fade t "$FADE" "$LOOPLEN" "$FADE"

# ---------------------------------------------------------------- langd
N=$(echo "scale=6; n=$TARGET_MIN*60/$LOOPLEN; scale=0; (n+0.9999)/1" | bc -l)
sox -G loop.flac lang.flac repeat $(( N - 1 ))

# En kort fil med bara skarven, tva sekunder fore och tva efter.
HALFJOIN=2
PRE=$(echo "$LOOPLEN - $HALFJOIN" | bc)
sox -G loop.flac /tmp/_a.flac trim "$PRE" "$HALFJOIN"
sox -G loop.flac /tmp/_b.flac trim 0 "$HALFJOIN"
sox -G /tmp/_a.flac /tmp/_b.flac skarv.flac
rm -f /tmp/_a.flac /tmp/_b.flac

printf 'loop.flac    %.3f s  (%s takter)\n' "$(soxi -D loop.flac)" "$BARS"
printf 'lang.flac    %.1f min  (%s varv)\n\n' "$(echo "$(soxi -D lang.flac) / 60" | bc -l)" "$N"
echo "Lyssna pa skarven:  play skarv.flac        (4 s, skarven i mitten)"
echo "Hela varvet:        play loop.flac repeat 2"
