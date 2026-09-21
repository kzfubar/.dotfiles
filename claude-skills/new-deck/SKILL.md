---
name: new-deck
description: Scaffold and build out a Slidev presentation deck in ~/decks, wire its per-deck MCP server, and review slides visually by rendering them to PNG. Use when asked to make, create, or build a presentation, deck, slides, or a talk. Triggers on "make me a deck", "new presentation", "build slides", "/new-deck", "deck about X", "slides for my talk".
---

# Building a deck

Workflow only. **Slidev syntax — layouts, `v-click`, magic-move, frontmatter, components,
export flags — lives in the `slidev` skill. Read that skill for syntax; do not restate it here.**

## Scaffold

Decks live in `~/decks/<name>`. Do not use `npm create slidev`: it always prompts
"Install and start it now?" with no flag to skip, and its template ships no `slides.md`.
Write the four files directly.

```bash
mkdir -p ~/decks/<name> && cd ~/decks/<name>
```

`package.json`:

```json
{
  "name": "<name>",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "slidev --open",
    "build": "slidev build",
    "export": "slidev export"
  },
  "dependencies": {
    "@slidev/cli": "^53.0.0",
    "@slidev/theme-default": "latest",
    "vue": "^3.5.33"
  },
  "devDependencies": {
    "playwright-chromium": "latest"
  }
}
```

`slides.md` — headmatter and a cover slide only. Content comes after the outline is agreed.

```md
---
theme: default
title: <Title>
css: unocss
---

# <Title>

<Subtitle>
```

`style.css` — the theme. Auto-injected by Slidev (`./style.css | ./styles/index.{css,js,ts}`).

`.gitignore` — `node_modules/`, `dist/`, `slides-export/`, `*.pdf`, `*.pptx`, `*.png`. (`slidev export --format png` writes to `slides-export/`.)

Then:

```bash
git init && npm install
```

`playwright-chromium` is a default dependency, not optional — visual review depends on it.

## Wire the MCP, scoped to this deck only

```bash
claude mcp add --scope local slidev -- npx slidev mcp slides.md
```

Use the **stdio** form, never `--transport http http://localhost:3030/__mcp`. The HTTP endpoint is
served by the dev server, so it requires the dev server to already be running and the port to
actually be 3030 (Slidev bumps it when occupied); a session started first finds a dead server.
stdio operates on the files directly — no dev server, no port.

`--scope local` is the CLI default and binds the server to this directory. It must never be added
at `user` scope: outside a deck there is nothing for it to talk to.

## Prefer MCP tools over text edits for slide operations

`slidev-list-slides`, `slidev-get-slide`, `slidev-update-slide`, `slidev-insert-slide`,
`slidev-remove-slide`, `slidev-move-slide`. They handle Slidev's compound separators correctly and
hot-reload a running dev server; raw text edits do neither.

Two constraints: slide 1 of the entry file cannot be removed or moved, because its frontmatter is
the deck headmatter. Moves cannot cross `src:` file boundaries.

## Keep content and theme separate

`slides.md` stays prose-only. Every visual decision — type scale, color, spacing, layout tweaks —
goes in `style.css`. Styling decided inline, slide by slide, drifts over a long editing session and
cannot be pulled back into alignment afterwards.

Scope every selector under `.slidev-layout`:

```css
.slidev-layout h1 { ... }    /* correct */
h1 { ... }                   /* leaks into the presenter UI */
```

Slidev injects this file into the app root, so unscoped global CSS also restyles presenter mode.

## Review slides visually — do not skip this

Markdown has no geometry. Overflow, cramped columns, and broken hierarchy are invisible in the
source and obvious in the render. After any substantive content change:

```bash
npm run export -- --format png              # all slides
npm run export -- --format png --range 3-7  # only what changed
```

Then **read the PNGs back** and fix what they show: content running off the bottom, headings that
do not establish hierarchy, low-contrast text, columns that collide. Repeat until clean.

Reporting a deck as done without having looked at a render is reporting it untested.

## Content density

One idea per slide. Default ceiling: **6 bullets, 10 words each** — confirm or override with the
user per deck, then hold to it. Prose written onto slides is the default failure mode; the budget
is the correction.

Speaker notes carry the detail that does not belong on the slide:

```md
<!--
The full argument goes here, not on the slide.
-->
```

## Handoff

Ask what the deck has to be at the end, because it changes the export:

| Need | Command |
|---|---|
| Present it yourself | `npm run dev` — no export |
| Send a read-only copy | `npm run export` (PDF, default) |
| Recipient opens in PowerPoint | `npm run export -- --format pptx-editable` |
| Recipient only views it | `npm run export -- --format pptx` (slides as images) |

`pptx-editable` rebuilds slides as native PowerPoint shapes with selectable text. SVG — including
Mermaid — canvas, iframes, KaTeX, gradients and CSS filters stay pictures; fonts are named, not
embedded; `--per-slide` is unsupported. Any slide it cannot rebuild falls back to image export on
its own.

## Order of work

1. Agree the outline and the content budget before writing slides.
2. Scaffold, install, wire the MCP.
3. Write content into `slides.md`, styling into `style.css`.
4. Render to PNG, read them, fix.
5. Export to the handoff format only once the render is clean.
