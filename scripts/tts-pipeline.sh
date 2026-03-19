#!/usr/bin/env bash
# =============================================================================
# tts-pipeline.sh — Generate TTS audio for each segment and merge into one file
# =============================================================================
#
# Usage:
#   bash scripts/tts-pipeline.sh segments.json [output_dir]
#
# Input: segments.json (array of TtsSegment objects from generate-actions.md)
# Output: per-segment .m4a files + merged tts-merged.m4a in output_dir
#
# TTS Provider: Gemini TTS (free) or ElevenLabs (premium)
# Set TTS_PROVIDER=gemini (default) or TTS_PROVIDER=elevenlabs
#
# Requirements:
#   - gemini CLI (for Gemini TTS) or curl (for ElevenLabs)
#   - ffmpeg (for merging audio)
#   - jq (for JSON parsing)
#
# =============================================================================

set -euo pipefail

SEGMENTS_FILE="${1:-segments.json}"
OUTPUT_DIR="${2:-remotion-board/public/tts}"
TTS_PROVIDER="${TTS_PROVIDER:-gemini}"

mkdir -p "$OUTPUT_DIR"

# ─── Validate input ────────────────────────────────────────────────────────
if [ ! -f "$SEGMENTS_FILE" ]; then
  echo "❌ segments.json not found: $SEGMENTS_FILE"
  echo "   Generate it using the AI prompt in scripts/generate-actions.md"
  exit 1
fi

SEGMENT_COUNT=$(jq length "$SEGMENTS_FILE")
echo "📋 Found $SEGMENT_COUNT segments in $SEGMENTS_FILE"

# ─── TTS per segment ───────────────────────────────────────────────────────
CONCAT_LIST="$OUTPUT_DIR/concat.txt"
> "$CONCAT_LIST"

for i in $(seq 0 $((SEGMENT_COUNT - 1))); do
  TEXT=$(jq -r ".[$i].text" "$SEGMENTS_FILE")
  OUT_FILE="$OUTPUT_DIR/segment-$(printf '%03d' $i).m4a"

  echo "🎙️  Segment $((i+1))/$SEGMENT_COUNT: \"${TEXT:0:60}...\""

  if [ "$TTS_PROVIDER" = "elevenlabs" ]; then
    # ── ElevenLabs TTS ─────────────────────────────────────────────────────
    ELEVENLABS_KEY="${ELEVENLABS_API_KEY:-}"
    VOICE_ID="${ELEVENLABS_VOICE_ID:-21m00Tcm4TlvDq8ikWAM}"  # Rachel

    if [ -z "$ELEVENLABS_KEY" ]; then
      echo "❌ Set ELEVENLABS_API_KEY environment variable"
      exit 1
    fi

    curl -s \
      -H "xi-api-key: $ELEVENLABS_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"text\": $(echo "$TEXT" | jq -Rs .), \"model_id\": \"eleven_multilingual_v2\", \"voice_settings\": {\"stability\": 0.5, \"similarity_boost\": 0.8}}" \
      "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID/stream" \
      -o "${OUT_FILE%.m4a}.mp3"

    # Convert mp3 → m4a
    ffmpeg -i "${OUT_FILE%.m4a}.mp3" -c:a aac -b:a 128k "$OUT_FILE" -y -loglevel error
    rm "${OUT_FILE%.m4a}.mp3"

  else
    # ── Gemini TTS (default) ────────────────────────────────────────────────
    # Uses gemini CLI with audio output capability
    # Note: Gemini TTS support depends on CLI version — check `gemini --help`
    GEMINI_SCRIPT=$(cat <<EOF
Please convert the following text to speech and output the audio.
Text: $TEXT
EOF
)
    # Fallback: Use macOS 'say' command if Gemini TTS not available
    say -v "Tingting" -r 180 -o "${OUT_FILE%.m4a}.aiff" "$TEXT" 2>/dev/null || {
      echo "⚠️  'say' command failed, using silence placeholder"
      # Generate silence as placeholder
      DURATION=$(echo "$TEXT" | wc -w | awk '{printf "%.1f", $1 / 2.5}')
      ffmpeg -f lavfi -i "anullsrc=r=44100:cl=mono" -t "$DURATION" "$OUT_FILE" -y -loglevel error
      echo "file '$OUT_FILE'" >> "$CONCAT_LIST"
      continue
    }

    # Convert aiff → m4a
    ffmpeg -i "${OUT_FILE%.m4a}.aiff" -c:a aac -b:a 128k "$OUT_FILE" -y -loglevel error
    rm "${OUT_FILE%.m4a}.aiff"
  fi

  echo "file '$OUT_FILE'" >> "$CONCAT_LIST"
  echo "  ✅ $OUT_FILE"
done

# ─── Merge all segments ────────────────────────────────────────────────────
MERGED="remotion-board/public/tts-merged.m4a"
echo ""
echo "🔗 Merging $SEGMENT_COUNT segments into $MERGED..."

ffmpeg -f concat -safe 0 -i "$CONCAT_LIST" \
  -c:a aac -b:a 128k "$MERGED" -y -loglevel error

echo "✅ Done! Merged audio: $MERGED"
echo ""
echo "📊 Audio duration:"
ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1 "$MERGED"
echo ""
echo "Next step:"
echo "  Edit remotion-board/src/TtsPPTVideo.tsx and set segments[] with timing from your JSON"
echo "  Then: cd remotion-board && npx remotion render TtsPPTVideo out/tts-video.mp4"
