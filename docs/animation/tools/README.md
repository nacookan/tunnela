# Regenerating the README video

The diagram lives as an HTML animation (`Tunnela Tunnel Animation.html` →
`anim.css` + `anim.js`). The README shows an **MP4 rendered from it**. When you
edit the animation, re-run one command and the video updates to match.

## Recommended: deterministic render (Playwright + ffmpeg)

```bash
./tools/record.sh
```

- Output: `../videos/tunnela-tunnels.mp4` (outside the git repo — **not committed**; **1920×1080, 60fps**, high quality)
- First run auto-installs Playwright + Chromium. `ffmpeg` must be installed
  (`brew install ffmpeg`).
- Knobs (env vars):
  - `SCALE` — `1.5` → 1920×1080 (default), `1` → 1280×720, `2` → 2560×1440
  - `FPS` — frames per second (default `60`)
  - `CRF` — quality, lower = better (default `16`; try `12` for near-lossless)
  - `BITRATE` — force an explicit bitrate, e.g. `BITRATE=30M ./tools/record.sh`

It works by driving the animation's `tunnelaSeek(t)` hook frame-by-frame, so the
result is pixel-identical every run — no window chrome, cursor, or timing drift.

## Embedding on GitHub

GitHub renders uploaded video as an inline player. In the README editor (or any
issue/PR comment), **drag the `.mp4` in** — GitHub returns a
`user-attachments` URL you can paste into `README.md`:

```markdown
https://github.com/user-attachments/assets/XXXXXXXX
```

(Committing the mp4 to the repo and linking it in Markdown will **not** autoplay;
the drag-and-drop upload is what produces the inline player.)

## Fallback: manual Safari screen-recording

If you'd rather not install Playwright:

1. Open `html/tunnela-tunnels.html` **with `#clean` appended** to the URL — this
   hides the controls and just loops the animation. (Pressing `h` toggles too.)
2. Size the Safari window so the diagram fills it (the board is 1280×720).
3. `Cmd+Shift+5` → record the diagram region for one loop (~29s).
4. Trim, then drag the file into the README as above.

This is fine for a one-off but isn't pixel-reproducible — prefer `record.sh` for
repeatable regeneration.
