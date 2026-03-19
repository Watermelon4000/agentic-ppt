# Generate SlideSpec + Action Sequence — AI Prompt Template

<!-- 設計決策：
  1. 這個 prompt 分為兩個 phase——Phase 1 生成 slides[] + metadata（結構化內容），
     Phase 2 從 SlideSpec + 音訊時序生成 actions[]（影片時間軸）。
  2. 採用 OpenMAIC 的 prompt 設計精髓：
     - "spotlight BEFORE speech" 排序原則
     - "不要描述你正在做什麼" 語音規則
     - 白板互斥清理規則
  3. 所有輸出必須通過 slide-spec-schema.json 驗證。
-->

---

## Phase 1: Generate SlideSpec (slides + metadata)

Use this prompt to produce structured slide content from a topic.

```
SYSTEM:
You are a presentation architect. You produce structured JSON matching
the SlideSpec schema. Every field you output must pass validation against
slide-spec-schema.json (JSON Schema Draft 2020-12).

USER:
TOPIC: [PASTE TOPIC / VIEWPOINT]
LANGUAGE: [zh-TW | zh-CN | en]
SLIDE COUNT: [5–10]
AUDIENCE: [e.g. "developers familiar with React"]
THEME: [sketch-notes | minimal | dark-pro | data-viz]  (default: sketch-notes)

TASK:
Produce a JSON object with two keys: "metadata" and "slides".

RULES:
1. One idea per slide. If content overflows, split into two slides.
2. Every slide MUST have:
   - "id": "slide-{N}" (0-indexed)
   - "layout": one of cover | content | grid | quote | takeaway
   - "title": string
3. Slide 0 MUST use layout "cover".
4. The last slide SHOULD use layout "takeaway".
5. Each body block MUST have a unique "elementId" following the pattern
   "{component}_{slideNum}_{index}", e.g. "bubble_0_1", "tool-card_2_0".
6. Use the right component for the content:
   - "bubble"        → quotes, key takeaways, the author's voice
   - "tool-card"     → comparing 4–6 items side by side (in grid layout)
   - "insight-card"  → 4–6 numbered insight/principle cards
   - "decision-tree" → "How to choose?" flows
   - "emphasis-box"  → single powerful statement
   - "compare-table" → head-to-head feature comparison
   - "text"          → regular paragraph text
   - "image"         → illustration or diagram
7. Card grid slides MUST use layout "grid" and have max 6 items.
8. Include "notes" on each slide — this becomes the TTS script.
9. Return ONLY the JSON object, no other text.

OUTPUT SCHEMA (abbreviated):
{
  "metadata": {
    "title": "...",
    "language": "zh-TW",
    "theme": "sketch-notes",
    "author": "...",
    "slideCount": 5
  },
  "slides": [
    {
      "id": "slide-0",
      "layout": "cover",
      "title": "...",
      "subtitle": "...",
      "body": [
        {
          "component": "bubble",
          "elementId": "bubble_0_0",
          "props": { "text": "..." }
        }
      ],
      "notes": "Speaker notes / TTS script for this slide."
    }
  ]
}
```

---

## Phase 2: Generate Actions (video timeline)

Use this prompt AFTER you have a SlideSpec (from Phase 1 or hand-authored).
The AI reads the SlideSpec + audio timing info and produces the `actions[]` array.

```
SYSTEM:
You are a video director generating a timed action sequence for a
presentation video rendered by Remotion. Your output is a JSON array
of action objects that controls slide transitions, whiteboard annotations,
subtitles, and visual effects.

Rules of engagement (borrowed from OpenMAIC's proven patterns):
- Spotlight BEFORE speech: always show "what to look at" before explaining it.
- Do NOT describe your actions: never say "let me show you" or "I'll now
  highlight". The viewer sees the effect — the narration should explain
  the CONCEPT, not the visual operation.
- Whiteboard hygiene: always wb_clear before writing new wb_write content
  on a different topic. Don't let stale whiteboard text linger.
- One transition per slide change: pair every advance_slide with a
  transition action at the same startTime for smooth visual flow.

USER:
SLIDESPEC (paste the full JSON from Phase 1):
[PASTE SLIDESPEC JSON]

AUDIO TIMING:
- Total duration: [DURATION] seconds
- Per-slide timing (from TTS alignment or manual timestamps):
  Slide 0: 0.0–12.5s
  Slide 1: 12.5–28.0s
  ...

TASK:
Produce a JSON array of actions. Each action has a "type" field and timing
fields in seconds.

AVAILABLE ACTION TYPES:

1. advance_slide — Switch to a slide
   { "type": "advance_slide", "slideIdx": 0, "startTime": 0 }

2. subtitle — Show subtitle text
   { "type": "subtitle", "text": "...", "startTime": 0, "duration": 4 }

3. wb_write — Draw text on the whiteboard overlay
   { "type": "wb_write", "text": "Key concept", "startTime": 5, "duration": 8 }

4. wb_clear — Clear the whiteboard
   { "type": "wb_clear", "startTime": 13 }

5. spotlight — Highlight an element with a banner
   { "type": "spotlight", "elementLabel": "bubble_0_0", "startTime": 2, "duration": 3 }

6. transition — Animate slide entrance
   { "type": "transition", "style": "fade", "startTime": 0, "duration": 0.8 }
   Styles: "fade" | "slide-left" | "slide-up"

7. zoom — Zoom into a target element
   { "type": "zoom", "target": "tool-card_2_0", "scale": 1.5, "startTime": 15, "duration": 4 }

ORDERING & TIMING RULES:
1. First action MUST be advance_slide to slideIdx 0 at startTime 0.
2. Pair each advance_slide with a transition at the same startTime.
3. Subtitle duration = max(word_count / 3, 1.5) seconds.
4. For CJK text, subtitle duration = max(char_count / 4, 1.5) seconds.
5. wb_write only for the MOST important concept per slide (1–2 per slide max).
6. Always wb_clear before the next wb_write if the topic changed.
7. spotlight should precede the subtitle that explains the spotlighted element.
8. zoom scale must be between 1.2 and 3.0, duration between 2 and 6 seconds.
9. No two actions of the same type should have overlapping time ranges.
10. All startTime values must be monotonically non-decreasing within each type.

RETURN ONLY the JSON array.
```

---

## Few-Shot Example

### Input

**Topic**: "為什麼你該用 AI 做簡報" (Why you should use AI for presentations)
**Language**: zh-TW, **Slides**: 5, **Theme**: sketch-notes
**Total audio duration**: 45 seconds

### Output: Full SlideSpec

```json
{
  "metadata": {
    "title": "為什麼你該用 AI 做簡報",
    "subtitle": "從手動排版到一鍵生成的思維轉變",
    "author": "Watermelon",
    "language": "zh-TW",
    "theme": "sketch-notes",
    "slideCount": 5
  },
  "slides": [
    {
      "id": "slide-0",
      "layout": "cover",
      "title": "為什麼你該用 AI 做簡報",
      "subtitle": "從手動排版到一鍵生成的思維轉變",
      "body": [
        {
          "component": "bubble",
          "elementId": "bubble_0_0",
          "props": { "text": "80% 的簡報時間花在排版，而不是思考內容。" }
        }
      ],
      "notes": "你有沒有想過，做一份簡報到底花了多少時間在排版上？研究顯示，80% 的時間都不是在思考內容。"
    },
    {
      "id": "slide-1",
      "layout": "grid",
      "title": "傳統做法的三大痛點",
      "body": [
        {
          "component": "insight-card",
          "elementId": "insight-card_1_0",
          "props": {
            "items": [
              { "number": "01", "title": "排版地獄", "description": "對齊、字體、間距，每次都重來" },
              { "number": "02", "title": "內容斷裂", "description": "思考被排版打斷，邏輯不連貫" },
              { "number": "03", "title": "風格不一", "description": "團隊協作時，每人一個風格" }
            ]
          }
        }
      ],
      "notes": "傳統做簡報有三大痛點。第一，排版地獄——對齊、字體、間距，每次都要重來。第二，內容斷裂——你的思考不斷被排版打斷。第三，風格不統一——團隊裡每個人做出來的都不一樣。"
    },
    {
      "id": "slide-2",
      "layout": "content",
      "title": "AI 簡報的工作流程",
      "body": [
        {
          "component": "tool-card",
          "elementId": "tool-card_2_0",
          "props": {
            "items": [
              { "icon": "💡", "tag": "INPUT", "title": "給主題", "description": "用一句話描述你的觀點" },
              { "icon": "🤖", "tag": "PROCESS", "title": "AI 生成", "description": "結構化內容 + 視覺排版一次完成" },
              { "icon": "✏️", "tag": "EDIT", "title": "微調", "description": "拖拽編輯器調整細節" },
              { "icon": "🎬", "tag": "OUTPUT", "title": "匯出", "description": "HTML / PNG / 影片，一鍵輸出" }
            ]
          }
        }
      ],
      "notes": "AI 簡報的流程非常簡單。你只需要給一個主題，AI 會同時完成結構化內容和視覺排版，你再用編輯器微調細節，最後一鍵匯出成 HTML、PNG 或影片。"
    },
    {
      "id": "slide-3",
      "layout": "content",
      "title": "AI vs 傳統：效率對比",
      "body": [
        {
          "component": "compare-table",
          "elementId": "compare-table_3_0",
          "props": {
            "columns": ["維度", "傳統方式", "AI 生成"],
            "rows": [
              ["製作時間", "2–4 小時", "5–10 分鐘"],
              ["風格一致性", "依賴模板", "自動統一"],
              ["內容結構", "手動規劃", "AI 建議"],
              ["影片轉換", "另外製作", "一鍵生成"]
            ]
          }
        }
      ],
      "notes": "來看一個直接的對比。傳統方式做一份簡報要 2 到 4 小時，AI 只要 5 到 10 分鐘。風格一致性、內容結構、影片轉換——每個維度 AI 都有明顯優勢。"
    },
    {
      "id": "slide-4",
      "layout": "takeaway",
      "title": "你的下一步",
      "body": [
        {
          "component": "bubble",
          "elementId": "bubble_4_0",
          "props": { "text": "把時間花在「說什麼」，而不是「怎麼排」。" }
        },
        {
          "component": "emphasis-box",
          "elementId": "emphasis-box_4_1",
          "props": { "text": "今天就試試 Agentic PPT — 用 AI 做你的第一份簡報。" }
        }
      ],
      "notes": "最重要的觀念轉變是：把時間花在「說什麼」，而不是「怎麼排」。今天就試試用 AI 做你的第一份簡報吧。"
    }
  ],
  "actions": [
    { "type": "advance_slide", "slideIdx": 0, "startTime": 0 },
    { "type": "transition", "style": "fade", "startTime": 0, "duration": 0.8 },
    { "type": "subtitle", "text": "你有沒有想過，做簡報到底花了多少時間在排版上？", "startTime": 0.5, "duration": 4.0 },
    { "type": "spotlight", "elementLabel": "bubble_0_0", "startTime": 4.5, "duration": 3.0 },
    { "type": "subtitle", "text": "研究顯示，80% 的時間都不是在思考內容。", "startTime": 5.0, "duration": 3.5 },

    { "type": "advance_slide", "slideIdx": 1, "startTime": 9.0 },
    { "type": "transition", "style": "slide-left", "startTime": 9.0, "duration": 0.6 },
    { "type": "subtitle", "text": "傳統做簡報有三大痛點。", "startTime": 9.5, "duration": 2.5 },
    { "type": "wb_write", "text": "排版 → 斷裂 → 不一致", "startTime": 10.0, "duration": 7.0 },
    { "type": "subtitle", "text": "排版地獄、內容斷裂、風格不統一。", "startTime": 12.5, "duration": 3.5 },
    { "type": "zoom", "target": "insight-card_1_0", "scale": 1.3, "startTime": 13.0, "duration": 3.0 },

    { "type": "wb_clear", "startTime": 17.5 },
    { "type": "advance_slide", "slideIdx": 2, "startTime": 18.0 },
    { "type": "transition", "style": "slide-left", "startTime": 18.0, "duration": 0.6 },
    { "type": "subtitle", "text": "AI 簡報的流程非常簡單。", "startTime": 18.5, "duration": 2.5 },
    { "type": "spotlight", "elementLabel": "tool-card_2_0", "startTime": 20.0, "duration": 3.0 },
    { "type": "subtitle", "text": "給主題、AI 生成、微調、匯出——四步完成。", "startTime": 21.0, "duration": 4.0 },
    { "type": "wb_write", "text": "主題 → 生成 → 微調 → 匯出", "startTime": 22.0, "duration": 5.0 },

    { "type": "wb_clear", "startTime": 27.5 },
    { "type": "advance_slide", "slideIdx": 3, "startTime": 28.0 },
    { "type": "transition", "style": "fade", "startTime": 28.0, "duration": 0.8 },
    { "type": "subtitle", "text": "來看一個直接的對比。", "startTime": 28.5, "duration": 2.0 },
    { "type": "zoom", "target": "compare-table_3_0", "scale": 1.4, "startTime": 30.0, "duration": 4.0 },
    { "type": "subtitle", "text": "傳統 2–4 小時，AI 只要 5–10 分鐘。", "startTime": 31.0, "duration": 3.5 },
    { "type": "wb_write", "text": "4 小時 → 10 分鐘", "startTime": 33.0, "duration": 5.0 },

    { "type": "wb_clear", "startTime": 38.5 },
    { "type": "advance_slide", "slideIdx": 4, "startTime": 39.0 },
    { "type": "transition", "style": "slide-up", "startTime": 39.0, "duration": 0.8 },
    { "type": "spotlight", "elementLabel": "bubble_4_0", "startTime": 39.5, "duration": 2.5 },
    { "type": "subtitle", "text": "把時間花在「說什麼」，而不是「怎麼排」。", "startTime": 40.0, "duration": 3.0 },
    { "type": "zoom", "target": "emphasis-box_4_1", "scale": 1.2, "startTime": 42.5, "duration": 2.5 },
    { "type": "subtitle", "text": "今天就試試用 AI 做你的第一份簡報吧。", "startTime": 43.0, "duration": 2.0 }
  ]
}
```

<!-- 設計註釋：
  - 這個 few-shot 示範了所有 7 種 action type 的正確用法
  - spotlight 總是在 subtitle 之前出現（OpenMAIC pattern）
  - 每次 advance_slide 都搭配一個 transition
  - wb_write 只用在最重要的概念（每張 slide 最多 1 次）
  - wb_clear 在切換話題前清除
  - zoom 用在需要觀眾仔細看的元素（表格、卡片）
-->

---

## Validation Rules

Before returning your output, self-check these rules:

<!-- 設計決策：這些規則讓 AI 在輸出前自我檢查，減少 JSON 錯誤。
     借鑑 OpenMAIC 的 action-parser.ts 容錯思路，但在 prompt 層面預防錯誤。 -->

| # | Rule | Check |
|---|------|-------|
| V1 | **Schema compliance** | Output must validate against `slide-spec-schema.json`. All `required` fields present. |
| V2 | **First action** | `actions[0]` must be `{ "type": "advance_slide", "slideIdx": 0, "startTime": 0 }`. |
| V3 | **slideIdx range** | Every `slideIdx` in actions must be `0 ≤ slideIdx < metadata.slideCount`. |
| V4 | **No time overlap** | No two actions of the same type should have overlapping `[startTime, startTime+duration)` ranges. |
| V5 | **Time bounds** | All `startTime + duration` values must be `≤ total audio duration`. |
| V6 | **transition pairing** | Every `advance_slide` should have a `transition` at the same `startTime`. |
| V7 | **wb_clear before wb_write** | If the previous `wb_write` topic differs, insert a `wb_clear` before the new one. |
| V8 | **spotlight ordering** | `spotlight.startTime` should be `≤` the `subtitle.startTime` that explains it. |
| V9 | **Subtitle length** | CJK: `duration ≥ char_count / 4`. Latin: `duration ≥ word_count / 3`. Minimum 1.5s. |
| V10 | **elementId consistency** | Any `elementLabel` or `target` in actions should match an `elementId` defined in `slides[].body[].elementId`. |

---

## TTS Segment Format (for TtsPPTVideo)

For the TTS-only video mode (no A-roll), generate `TtsSegment[]` instead of `actions[]`.
This is a simplified format where each segment maps to one TTS audio clip.

```
TASK:
Produce a JSON array of TtsSegment objects derived from the SlideSpec's
slide notes.

INPUT:
- SlideSpec JSON (with "notes" on each slide)
- SLIDE MAP (optional — override which slide covers which segment)

OUTPUT FORMAT:
[
  {
    "text": "First sentence spoken aloud",
    "startTime": 0,
    "duration": 4.2,
    "slideIdx": 0,
    "wbText": "Optional key concept for whiteboard"
  },
  ...
]

RULES:
- startTime for segment N = sum of all previous durations + (N × 0.3) gap
- duration estimate: CJK = char_count / 4 seconds, Latin = word_count / 2.5
- wbText = optional, only for the most important key concept per slide
- slideIdx changes when the topic transitions to the next slide
- Split long notes into multiple segments (max ~30 chars CJK / ~15 words per segment)
```

Then run the TTS pipeline:
```bash
bash scripts/tts-pipeline.sh segments.json
```

---

## After Getting the JSON

1. **Save** the SlideSpec as `slidespec.json` in your project folder.

2. **Validate** against the schema:
   ```bash
   npx ajv-cli validate -s scripts/slide-spec-schema.json -d slidespec.json --spec=draft2020
   ```

3. **For HTML rendering**: Pass the SlideSpec to the agentic-ppt SKILL —
   it reads `slides[]` and generates the single-file HTML deck.

4. **For Remotion rendering**: Import and pass to the component:
   ```typescript
   import spec from './slidespec.json';

   // In Root.tsx defaultProps:
   defaultProps={{
     layout: '16x9',
     arollSrc: 'aroll.mp4',
     audioSrc: 'narration.m4a',
     actions: spec.actions,
     slides: [Slide0, Slide1, Slide2, Slide3, Slide4],
   }}
   ```

5. **Render**:
   ```bash
   cd remotion-board
   # A-roll + slides (16:9)
   npx remotion render AgenticPPTVideo out/video.mp4
   # A-roll + slides (9:16)
   npx remotion render AgenticPPTVideo-9x16 out/video-9x16.mp4
   # TTS only (no A-roll)
   npx remotion render TtsPPTVideo out/tts-video.mp4
   ```
