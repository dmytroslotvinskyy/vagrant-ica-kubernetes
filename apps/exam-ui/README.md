# Bun Task Viewer UI

A minimal Bun-powered web application that mirrors the 16-task mock exam experience with a split-pane layout, search, and client-side flagging.

## Prerequisites

- [Bun](https://bun.sh) v1.1 or newer installed on your host (the server uses native `bun serve`).

## Quick start

```bash
cd apps/exam-ui
bun run dev
```

By default the server watches `/vagrant/exam-tasks.md` (relative to the repository root) and serves the UI on <http://localhost:4173>. Changes to `exam-tasks.md` hot-reload automatically thanks to Bun's `--watch` flag.

### Customizing the task source

Point the server at another markdown file with `TASK_FILE`:

```bash
TASK_FILE=/path/to/tasks.md bun run dev
```

### Production-style run

```bash
bun run start
```

This launches the same Bun server without the watch flag (useful when deploying or running under a supervisor).

## UI features

- Sticky navigation with search/filter support (All vs Flagged)
- Inline flag toggles stored in `localStorage`, so you can mark tasks while referencing docs or the tmux helper
- Markdown-like rendering with inline code, emphasis, and bullet list support
- Fully responsive layout for narrow screens

Because the API is just `/api/tasks`, you can also embed this UI behind port-forwarding or reverse proxies (e.g., `ssh -L 4173:localhost:4173 controlplane`).
