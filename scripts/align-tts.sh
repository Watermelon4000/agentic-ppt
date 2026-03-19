#!/usr/bin/env bash
# =============================================================================
# align-tts.sh — Generate TTS audio per segment and auto-align timing
# =============================================================================
#
# Usage:
#   bash scripts/align-tts.sh [options] <segments.json>
#
# Options:
#   --provider <elevenlabs|say>   TTS provider (default: say)
#   --voice-id <id>               ElevenLabs voice ID (default: 21m00Tcm4TlvDq8ikWAM)
#   --gap <seconds>               Gap between segments (default: 0.3)
#   --output <dir>                Output directory (default: output)
#   --dry-run                     Skip TTS calls; reuse existing .mp3 or generate
#                                 silence placeholders, then compute timing only
#   -h, --help                    Show this help message
#
# Input format (segments.json):
#   [
#     { "text": "大家好...", "slideIdx": 0, "wbText": "Hello" },
#     { "text": "第二段...", "slideIdx": 1 },
#     ...
#   ]
#
# Output:
#   <output>/segment-001.mp3, segment-002.mp3, ...
#   <output>/aligned-segments.json   (with startTime & duration filled in)
#   <output>/tts-merged.m4a          (all segments concatenated)
#
# Environment variables:
#   ELEVENLABS_API_KEY   Required when --provider elevenlabs
#   ELEVENLABS_VOICE_ID  Override default voice (same as --voice-id)
#
# Dependencies: ffmpeg, ffprobe, jq
# =============================================================================

set -euo pipefail

# ─── Defaults ──────────────────────────────────────────────────────────────────
PROVIDER="say"
VOICE_ID="${ELEVENLABS_VOICE_ID:-21m00Tcm4TlvDq8ikWAM}"
GAP=0.3
OUTPUT_DIR="output"
DRY_RUN=false
SEGMENTS_FILE=""

# ─── Parse arguments ──────────────────────────────────────────────────────────
usage() {
  sed -n '2,/^# ===.*===$/p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)     usage ;;
    --provider)    PROVIDER="$2"; shift 2 ;;
    --voice-id)    VOICE_ID="$2"; shift 2 ;;
    --gap)         GAP="$2"; shift 2 ;;
    --output)      OUTPUT_DIR="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    -*)            echo "❌ Unknown option: $1"; usage ;;
    *)             SEGMENTS_FILE="$1"; shift ;;
  esac
done

if [[ -z "$SEGMENTS_FILE" ]]; then
  echo "❌ Missing required argument: <segments.json>"
  echo "   Run with --help for usage."
  exit 1
fi

# ─── Dependency check ─────────────────────────────────────────────────────────
missing=()
for cmd in ffmpeg ffprobe jq; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "❌ Missing dependencies: ${missing[*]}"
  echo "   Install with: brew install ${missing[*]}"
  exit 1
fi

# ─── Validate input ───────────────────────────────────────────────────────────
if [[ ! -f "$SEGMENTS_FILE" ]]; then
  echo "❌ File not found: $SEGMENTS_FILE"
  exit 1
fi

SEGMENT_COUNT=$(jq 'length' "$SEGMENTS_FILE")
if [[ "$SEGMENT_COUNT" -eq 0 ]]; then
  echo "❌ segments.json is empty"
  exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "  align-tts.sh"
echo "  Provider : $PROVIDER"
echo "  Segments : $SEGMENT_COUNT"
echo "  Gap      : ${GAP}s"
echo "  Output   : $OUTPUT_DIR"
echo "  Dry-run  : $DRY_RUN"
echo "═══════════════════════════════════════════════════════════════"
echo ""

mkdir -p "$OUTPUT_DIR"

# ─── TTS generation per segment ────────────────────────────────────────────────
generate_tts_elevenlabs() {
  local text="$1" out_file="$2"
  local api_key="${ELEVENLABS_API_KEY:-}"

  if [[ -z "$api_key" ]]; then
    echo "❌ ELEVENLABS_API_KEY is not set"
    exit 1
  fi

  curl -s --fail \
    -H "xi-api-key: $api_key" \
    -H "Content-Type: application/json" \
    -d "{\"text\": $(echo "$text" | jq -Rs .), \"model_id\": \"eleven_multilingual_v2\", \"voice_settings\": {\"stability\": 0.5, \"similarity_boost\": 0.8}}" \
    "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID/stream" \
    -o "$out_file"
}

generate_tts_say() {
  local text="$1" out_file="$2"
  local tmp_aiff="${out_file%.mp3}.aiff"

  # Use Tingting for Chinese, fallback to default
  say -v "Tingting" -r 180 -o "$tmp_aiff" "$text" 2>/dev/null || \
    say -r 180 -o "$tmp_aiff" "$text"

  ffmpeg -i "$tmp_aiff" -codec:a libmp3lame -b:a 128k "$out_file" -y -loglevel error
  rm -f "$tmp_aiff"
}

generate_silence_mp3() {
  local text="$1" out_file="$2"
  # Estimate duration: ~2.5 words/sec for Chinese (count chars), ~3 words/sec for English
  local char_count
  char_count=$(echo -n "$text" | wc -m | tr -d ' ')
  local duration
  duration=$(awk "BEGIN {d = $char_count / 4.0; if (d < 1) d = 1; printf \"%.1f\", d}")
  ffmpeg -f lavfi -i "anullsrc=r=44100:cl=mono" -t "$duration" \
    -codec:a libmp3lame -b:a 128k "$out_file" -y -loglevel error
}

# ─── Get precise duration via ffprobe ──────────────────────────────────────────
get_duration() {
  ffprobe -v quiet -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$1"
}

# ─── Main loop ─────────────────────────────────────────────────────────────────
DURATIONS=()
FILES=()

for i in $(seq 0 $((SEGMENT_COUNT - 1))); do
  idx=$(printf '%03d' "$((i + 1))")
  TEXT=$(jq -r ".[$i].text" "$SEGMENTS_FILE")
  OUT_FILE="$OUTPUT_DIR/segment-${idx}.mp3"

  echo "🎙️  [$idx/$SEGMENT_COUNT] \"${TEXT:0:50}...\""

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$OUT_FILE" ]]; then
      echo "  ⏩ Dry-run: reusing existing $OUT_FILE"
    else
      echo "  ⏩ Dry-run: generating silence placeholder"
      generate_silence_mp3 "$TEXT" "$OUT_FILE"
    fi
  else
    case "$PROVIDER" in
      elevenlabs) generate_tts_elevenlabs "$TEXT" "$OUT_FILE" ;;
      say)        generate_tts_say "$TEXT" "$OUT_FILE" ;;
      *)          echo "❌ Unknown provider: $PROVIDER"; exit 1 ;;
    esac
  fi

  # Measure duration
  DUR=$(get_duration "$OUT_FILE")
  DURATIONS+=("$DUR")
  FILES+=("$OUT_FILE")
  echo "  ✅ ${DUR}s → $OUT_FILE"
done

echo ""

# ─── Compute aligned timing ───────────────────────────────────────────────────
echo "📐 Computing aligned timing (gap=${GAP}s)..."

ALIGNED_FILE="$OUTPUT_DIR/aligned-segments.json"
CURRENT_TIME=0

# Build aligned JSON using jq
jq -n --argjson segments "$(cat "$SEGMENTS_FILE")" \
      --argjson durations "$(printf '%s\n' "${DURATIONS[@]}" | jq -s '.')" \
      --argjson gap "$GAP" '
  [range($segments | length)] |
  map(. as $i |
    ($durations[:$i] | add // 0) as $prev_dur_sum |
    ($i * $gap) as $gap_sum |
    ($prev_dur_sum + $gap_sum) as $start |
    $segments[$i] + {
      "startTime": ($start * 100 | round / 100),
      "duration":  ($durations[$i] * 100 | round / 100)
    }
  )
' > "$ALIGNED_FILE"

echo "  ✅ $ALIGNED_FILE"
echo ""

# Print timing table
echo "┌───────┬────────────┬────────────┬──────────────────────────────────────┐"
echo "│  Seg  │  startTime │  duration  │  text                                │"
echo "├───────┼────────────┼────────────┼──────────────────────────────────────┤"
jq -r '
  .[] | @text "\(.startTime)\t\(.duration)\t\(.text)"
' "$ALIGNED_FILE" | awk -F'\t' '{
  printf "│  %03d  │  %8.2fs │  %8.2fs │  %-36.36s │\n", NR, $1, $2, $3
}'
echo "└───────┴────────────┴────────────┴──────────────────────────────────────┘"

# Total duration
TOTAL=$(jq '[.[-1].startTime, .[-1].duration] | add' "$ALIGNED_FILE")
echo ""
echo "⏱️  Total estimated duration: ${TOTAL}s"

# ─── Merge audio ───────────────────────────────────────────────────────────────
MERGED="$OUTPUT_DIR/tts-merged.m4a"
echo ""
echo "🔗 Merging ${#FILES[@]} segments into $MERGED..."

# Build filter_complex concat with silence gaps between segments
FILTER=""
INPUT_ARGS=()
STREAM_IDX=0

for i in $(seq 0 $((${#FILES[@]} - 1))); do
  INPUT_ARGS+=(-i "${FILES[$i]}")

  if [[ $i -gt 0 ]]; then
    # Add silence gap before this segment
    INPUT_ARGS+=(-f lavfi -t "$GAP" -i "anullsrc=r=44100:cl=stereo")
  fi
done

# Build concat filter
# Input layout: [seg0] [gap] [seg1] [gap] [seg2] ...
# Stream indices: 0=seg0, 1=gap, 2=seg1, 3=gap, 4=seg2 ...
TOTAL_INPUTS=$(( ${#FILES[@]} * 2 - 1 ))
FILTER_INPUTS=""
for j in $(seq 0 $((TOTAL_INPUTS - 1))); do
  FILTER_INPUTS+="[$j:a]"
done

ffmpeg "${INPUT_ARGS[@]}" \
  -filter_complex "${FILTER_INPUTS}concat=n=${TOTAL_INPUTS}:v=0:a=1[out]" \
  -map "[out]" -c:a aac -b:a 128k "$MERGED" -y -loglevel error

MERGED_DUR=$(get_duration "$MERGED")
echo "  ✅ $MERGED (${MERGED_DUR}s)"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ All done!"
echo ""
echo "  Audio files : $OUTPUT_DIR/segment-*.mp3"
echo "  Timing JSON : $ALIGNED_FILE"
echo "  Merged audio: $MERGED"
echo ""
echo "  Next: Feed aligned-segments.json into TtsPPTVideo.tsx"
echo "═══════════════════════════════════════════════════════════════"
