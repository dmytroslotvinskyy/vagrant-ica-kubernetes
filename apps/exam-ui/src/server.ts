import { readFile, stat } from "fs/promises";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC_ROOT = new URL("../public/", import.meta.url);
const DEFAULT_TASK_FILE = resolve(__dirname, "../../exam-tasks.md");
const TASK_FILE = process.env.TASK_FILE ? resolve(process.env.TASK_FILE) : DEFAULT_TASK_FILE;

const PORT = Number(process.env.PORT ?? 4173);

interface TaskPayload {
  id: number;
  title: string;
  subtitle: string;
  points?: number;
  summary: string;
  html: string;
}

let cachedTimestamp = 0;
let cachedTasks: TaskPayload[] = [];

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function formatInline(text: string): string {
  return escapeHtml(text)
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
}

function paragraphToHtml(block: string): string {
  const lines = block.split(/\n+/).map((line) => line.trim()).filter(Boolean);
  if (!lines.length) return "";
  const isList = lines.every((line) => /^[-*]\s+/.test(line));
  if (isList) {
    const items = lines
      .map((line) => line.replace(/^[-*]\s+/, ""))
      .map((line) => `<li>${formatInline(line)}</li>`) 
      .join("");
    return `<ul>${items}</ul>`;
  }
  return `<p>${formatInline(lines.join(" "))}</p>`;
}

function convertMarkdown(body: string): string {
  const paragraphs = body.split(/\n\s*\n/).map((segment) => segment.trim()).filter(Boolean);
  if (!paragraphs.length) {
    return "<p class=\"empty\">No additional details provided.</p>";
  }
  return paragraphs.map(paragraphToHtml).join("\n");
}

function parseTasks(raw: string): TaskPayload[] {
  return raw
    .split(/---TASK---/)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block, index) => {
      const [titleLine, ...rest] = block.split(/\n/);
      const titleText = titleLine?.replace(/^#+\s*/, "").trim() ?? `Task ${index + 1}`;
      const match = titleText.match(/Task\s+(\d+)\s*\((\d+)\s*pts?\)\s*[–-]\s*(.+)/i);
      const id = match ? Number(match[1]) : index + 1;
      const points = match ? Number(match[2]) : undefined;
      const subtitle = match ? match[3].trim() : titleText;
      const summary = rest.join("\n").trim();
      return {
        id,
        title: `Task ${id}`,
        subtitle,
        points,
        summary,
        html: convertMarkdown(summary),
      } satisfies TaskPayload;
    })
    .sort((a, b) => a.id - b.id);
}

async function loadTasks(): Promise<TaskPayload[]> {
  const info = await stat(TASK_FILE);
  if (info.mtimeMs === cachedTimestamp && cachedTasks.length) {
    return cachedTasks;
  }
  const raw = await readFile(TASK_FILE, "utf8");
  cachedTasks = parseTasks(raw);
  cachedTimestamp = info.mtimeMs;
  return cachedTasks;
}

async function serveStatic(pathname: string): Promise<Response | null> {
  const target = pathname === "/" ? "/index.html" : pathname;
  const fileUrl = new URL(`.${target}`, PUBLIC_ROOT);
  const file = Bun.file(fileUrl);
  if (!(await file.exists())) {
    return null;
  }
  const type = Bun.mime.get(file.name) ?? "application/octet-stream";
  return new Response(file, {
    headers: {
      "Content-Type": type,
      "Cache-Control": target === "/index.html" ? "no-cache" : "max-age=0",
    },
  });
}

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === "/api/tasks") {
      const tasks = await loadTasks();
      return new Response(JSON.stringify({ tasks, updatedAt: cachedTimestamp }), {
        headers: { "Content-Type": "application/json" },
      });
    }
    const asset = await serveStatic(url.pathname);
    if (asset) return asset;
    const fallback = await serveStatic("/index.html");
    return fallback ?? new Response("Not Found", { status: 404 });
  },
});

console.log(`[exam-ui] running on http://localhost:${server.port}`);
console.log(`[exam-ui] reading tasks from ${TASK_FILE}`);
