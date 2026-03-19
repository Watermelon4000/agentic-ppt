<div align="center">

# 🎨 Agentic PPT

**AI-generated Sketch Notes presentations — HTML slides, drag editor, and explainer videos**

[Demo](#-demo) · [Quick Start](#-quick-start) · [Canvas Editor](#️-canvas-drag-editor) · [Video Pipeline](#-video-pipeline) · [AI Tools](#-use-with-ai-coding-tools) · [Design Guide](style/STYLE_GUIDE.md)

</div>

---

## What is this?

**Agentic PPT** is a 4-tool toolkit for turning ideas into polished presentations and explainer videos using AI — with a distinctive **Sketch Notes** visual style (manga-inspired: comic borders, speech bubbles, halftone, crosshatch).

| Tool | What it does |
|------|-------------|
| 🎨 **HTML PPT Generator** | AI generates a self-contained HTML deck from any topic |
| ✏️ **Canvas Drag Editor** | Browser editor: drag elements, edit text, export PNG or HTML |
| 🎬 **A-roll → Video** | A-roll face cam + slides → 16:9 / 9:16 explainer video (Remotion) |
| 🎙️ **TTS → Video** | Script → TTS audio → animated whiteboard video (no A-roll needed) |

> **Philosophy:** One idea per slide. One personality per deck.

---

## 🎨 Demo

Open [`demo/demo-index.html`](demo/demo-index.html) in your browser.

**Keyboard shortcuts:**
| Key | Action |
|-----|--------|
| `→` or `Space` | Next slide |
| `←` | Previous slide |
| Swipe left/right | Mobile navigation |

---

## 🚀 Quick Start

### Option A: Let AI generate a new deck

1. Copy [`skill/SKILL.md`](skill/SKILL.md) into your AI agent (Antigravity, Claude, etc.)
2. Tell the AI: *"Make a PPT about [your topic]"*
3. The AI outputs a complete `.html` file — open in browser, done!

### Option B: Build from the template

1. Copy `demo/demo-index.html` as a starting point
2. Edit slide content directly in HTML

### Option C: Use the CSS library

```html
<link rel="stylesheet" href="style/sketch-notes-base.css">
```

---

## ✏️ Canvas Drag Editor

Open [`editor/editor.html`](editor/editor.html) in your browser to visually edit any generated slide.

**Features:**
- 🖱️ **Drag** any element to reposition (8px grid snap)
- 🔠 **Double-click** to edit text inline
- 📐 **Resize** elements via bottom-right handle
- 🎨 **Properties panel** — change color, font size, opacity
- 💾 **Save HTML** — downloads modified presentation
- 🖼️ **Export PNG** — screenshots current slide via html2canvas

**Usage:** Click "Load HTML" → choose your `.html` deck → click "Enable Editing"

---

## 🎬 Video Pipeline

Turn your Sketch Notes deck into a narrated explainer video using [Remotion](https://remotion.dev).

### Prerequisites

```bash
cd remotion-board
npm install
```

### A-roll → Explainer Video (Feature 3)

```
Input: your face-cam recording + HTML slides + narration audio
Output: 16:9 or 9:16 MP4 video

16:9 layout: A-roll (22% left) | Slide (74% right)
9:16 layout: Slide fullscreen + A-roll PiP (bottom-right corner)
```

1. Copy your A-roll to `remotion-board/public/aroll.mp4`
2. Copy narration audio to `remotion-board/public/narration.m4a`
3. Generate action sequence JSON using [`scripts/generate-actions.md`](scripts/generate-actions.md)
4. Render:

```bash
# 16:9 (YouTube / landscape)
npx remotion render AgenticPPTVideo out/video.mp4

# 9:16 (Shorts / Reels / TikTok)
npx remotion render AgenticPPTVideo-9x16 out/video-9x16.mp4
```

### TTS → Explainer Video (Feature 4)

```
Input: script text
Output: animated whiteboard MP4 (no A-roll needed)
```

1. Write your `segments.json` (see [`scripts/generate-actions.md`](scripts/generate-actions.md))
2. Generate TTS audio:

```bash
# ElevenLabs (high quality)
ELEVENLABS_API_KEY=xxx TTS_PROVIDER=elevenlabs bash scripts/tts-pipeline.sh segments.json

# macOS say (free, built-in)
bash scripts/tts-pipeline.sh segments.json
```

3. Render:

```bash
npx remotion render TtsPPTVideo out/tts-video.mp4
```

---

## 🤖 Use with AI Coding Tools

The [`skill/SKILL.md`](skill/SKILL.md) file is a universal instruction set that works with any AI coding assistant. Pick your tool:

### Antigravity (Google Agent Manager)

```bash
# Install as a skill
cp skill/SKILL.md ~/.gemini/antigravity/skills/agentic-ppt/SKILL.md
```

Trigger: *"做一個 PPT 關於 [主題]"* or *"Make a PPT about [topic]"*

### Claude Code

```bash
# Add SKILL.md as project context
claude --project-context skill/SKILL.md
# Then ask:
claude "Make a PPT about [topic], follow the instructions in SKILL.md"
```

Or paste `skill/SKILL.md` content directly into the conversation as system instructions.

### OpenAI Codex

```bash
# Reference SKILL.md in your prompt
codex "Read skill/SKILL.md and generate a PPT about [topic]"
```

### Gemini CLI

```bash
# Use @file syntax to include SKILL.md
gemini "Generate a presentation about [topic] following these instructions: @skill/SKILL.md"
```

### OpenClaw

Add `skill/SKILL.md` as a skill file in your OpenClaw configuration, then trigger via Discord/chat.

### Any Other AI Tool

The skill works with **any** LLM that can follow markdown instructions:

1. Copy the contents of [`skill/SKILL.md`](skill/SKILL.md)
2. Paste it into the AI's system prompt or conversation
3. Ask: *"Make a PPT about [your topic]"*
4. The AI outputs a self-contained `.html` file — open in browser, done!

---

## 🎨 Visual Components

See [`style/STYLE_GUIDE.md`](style/STYLE_GUIDE.md) for full details.

| Component | Class | Best For |
|-----------|-------|---------| 
| Speech bubble | `.bubble` | Key takeaways, author voice |
| Tool cards | `.tools-grid` + `.tool-card` | Comparing 4–6 items |
| Insight cards | `.insight-grid` + `.insight-card` | Numbered principles |
| Decision tree | `.decision-tree` | "How to choose?" flows |
| Comparison table | `.compare-table` | Head-to-head features |
| Emphasis box | `.emphasis-box` | One powerful statement |

---

## License

MIT — use freely, attribution appreciated.

---

<div align="center">

Made with ✦ AI + human taste

</div>
