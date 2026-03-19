import React from 'react';
import {
  AbsoluteFill,
  Audio,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  staticFile,
} from 'remotion';
import type { Action } from './types';

// Re-export Action type from shared module
export type { Action } from './types';

// ============================================================
// TYPES
// ============================================================

export interface TtsSegment {
  /** Text spoken in this segment */
  text: string;
  /** Start time in seconds */
  startTime: number;
  /** Duration in seconds (matches TTS audio length) */
  duration: number;
  /** Which slide to show during this segment (0-indexed) */
  slideIdx: number;
  /** Optional whiteboard text to draw during this segment */
  wbText?: string;
}

export interface TtsPPTProps {
  /** Audio files per segment, in public/ */
  audioPaths?: string[];
  /** Merged single audio file (alternative to per-segment files) */
  mergedAudioSrc?: string;
  /** Slide components */
  slides?: React.FC[];
  /** Ordered segments with timing */
  segments?: TtsSegment[];
}

// ============================================================
// DESIGN TOKENS
// ============================================================
const PAPER = '#f5f0e8';
const INK   = '#1a1a1a';
const GREY  = '#888';
const LIGHT_GREY = '#d0ccc4';
const TEAL  = '#4ECDC4';

// ============================================================
// DECORATIONS
// ============================================================
const Halftone = () => (
  <div style={{
    position: 'absolute', inset: 0, opacity: 0.04, pointerEvents: 'none',
    backgroundImage: `radial-gradient(circle, ${INK} 1px, transparent 1px)`,
    backgroundSize: '6px 6px',
  }} />
);

const ComicBorder = () => (
  <>
    <div style={{position:'absolute',inset:18,border:`3.5px solid ${INK}`,borderRadius:2,pointerEvents:'none',zIndex:1}} />
    <div style={{position:'absolute',inset:14,border:`1px solid ${LIGHT_GREY}`,pointerEvents:'none',zIndex:1}} />
  </>
);

// ============================================================
// WHITEBOARD — fullscreen right-side panel (TTS mode)
// ============================================================
const WhiteboardPanel: React.FC<{
  text: string;
  progress: number; // 0→1 draw-in progress
}> = ({ text, progress }) => {
  if (!text || progress === 0) return null;
  return (
    <div style={{
      position: 'absolute',
      top: 24, right: 24, bottom: 80,
      width: '30%',
      background: '#fff',
      border: `2.5px solid ${INK}`,
      borderRadius: 4,
      padding: '20px 24px',
      boxShadow: `4px 4px 0 ${INK}`,
      zIndex: 80,
    }}>
      <div style={{
        fontFamily: "'Permanent Marker', cursive",
        fontSize: 12,
        color: GREY,
        letterSpacing: 2,
        marginBottom: 12,
        borderBottom: `2px solid ${LIGHT_GREY}`,
        paddingBottom: 8,
      }}>
        WHITEBOARD
      </div>
      <div style={{
        fontFamily: "'Caveat', cursive",
        fontSize: 26,
        fontWeight: 700,
        color: INK,
        lineHeight: 1.5,
        opacity: progress,
        transform: `translateY(${(1 - progress) * 10}px)`,
        transition: 'none', // Remotion handles interpolation per-frame
      }}>
        {text}
      </div>
    </div>
  );
};

// ============================================================
// SUBTITLE BAR
// ============================================================
const SubtitleBar: React.FC<{ text: string }> = ({ text }) => (
  <div style={{
    position: 'absolute', bottom: 0, left: 0, right: 0,
    padding: '14px 32px',
    background: PAPER, borderTop: `2.5px solid ${INK}`,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    minHeight: 60, zIndex: 100,
  }}>
    <div style={{
      fontFamily: "'Noto Sans SC', sans-serif",
      fontSize: 26, fontWeight: 500, color: text ? INK : 'transparent',
      textAlign: 'center', maxWidth: 900,
    }}>
      {text}
    </div>
  </div>
);

// ============================================================
// PROGRESS INDICATOR
// ============================================================
const ProgressBar: React.FC<{ progress: number }> = ({ progress }) => (
  <div style={{
    position: 'absolute', top: 0, left: 0, right: 0, height: 4, zIndex: 200,
  }}>
    <div style={{
      height: '100%', background: TEAL,
      width: `${progress * 100}%`,
    }} />
  </div>
);

// ============================================================
// PLACEHOLDER SLIDE
// ============================================================
const PlaceholderSlide: React.FC<{ idx: number }> = ({ idx }) => (
  <div style={{ fontFamily: "'Permanent Marker', cursive", fontSize: 48, color: INK, position: 'relative', zIndex: 5 }}>
    Slide {idx + 1}
  </div>
);

// ============================================================
// MAIN COMPOSITION
// ============================================================

/**
 * TtsPPTVideo — Script + TTS Audio → Animated whiteboard explainer video
 *
 * No A-roll needed. The full slide area is used, with whiteboard panel overlay.
 *
 * Usage:
 *   1. Generate TTS audio per segment:
 *      bash scripts/tts-pipeline.sh segments.json
 *
 *   2. Edit SEGMENTS array below with timing from the generated audio.
 *
 *   3. Render:
 *      npx remotion render TtsPPTVideo out/tts-video.mp4
 *
 * See scripts/generate-actions.md for the AI prompt to auto-generate segments.
 */
export const TtsPPTVideo: React.FC<TtsPPTProps> = ({
  mergedAudioSrc = 'tts-merged.m4a',
  slides = [],
  segments = [],
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const t = frame / fps;
  const totalDuration = durationInFrames / fps;

  // ── Current segment ──────────────────────────────────────
  const currentSegment = [...segments].reverse().find((s: TtsSegment) => t >= s.startTime);


  const slideIdx = currentSegment?.slideIdx ?? 0;
  const SlideComponent = slides[slideIdx] ?? (() => <PlaceholderSlide idx={slideIdx} />);

  // ── Whiteboard draw-in progress ──────────────────────────
  let wbProgress = 0;
  let wbText = '';
  if (currentSegment?.wbText && t >= currentSegment.startTime) {
    wbText = currentSegment.wbText;
    wbProgress = interpolate(
      t,
      [currentSegment.startTime, currentSegment.startTime + 0.5],
      [0, 1],
      { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
    );
  }

  // ── Subtitle ──────────────────────────────────────────────
  const subtitleText = currentSegment?.text ?? '';

  return (
    <AbsoluteFill style={{ fontFamily: "'Noto Sans SC', sans-serif", backgroundColor: PAPER, color: INK }}>
      <Halftone />
      <ProgressBar progress={t / totalDuration} />

      {/* Full-screen slide */}
      <AbsoluteFill style={{
        display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        background: PAPER, padding: '60px 80px', textAlign: 'center',
      }}>
        <ComicBorder />
        <SlideComponent />
      </AbsoluteFill>

      {/* Whiteboard overlay */}
      <WhiteboardPanel text={wbText} progress={wbProgress} />

      <SubtitleBar text={subtitleText} />

      {/* Merged TTS audio */}
      {mergedAudioSrc && <Audio src={staticFile(mergedAudioSrc)} />}
    </AbsoluteFill>
  );
};

export default TtsPPTVideo;
