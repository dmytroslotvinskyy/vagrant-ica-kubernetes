#!/usr/bin/env bun
import blessed from "blessed";
import { readFile } from "fs/promises";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { existsSync } from "fs";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Try multiple locations for the task file
const POSSIBLE_TASK_FILES = [
  process.env.TASK_FILE,
  "/vagrant/exam-tasks.md",
  resolve(__dirname, "../../exam-tasks.md"),
  "./exam-tasks.md",
].filter(Boolean);

// Find the first task file that exists
const DEFAULT_TASK_FILE = POSSIBLE_TASK_FILES.find(path => {
  try {
    return existsSync(path!);
  } catch {
    return false;
  }
}) || "/vagrant/exam-tasks.md";

const TASK_FILE = process.env.TASK_FILE ? resolve(process.env.TASK_FILE) : DEFAULT_TASK_FILE;
const FLAG_FILE = process.env.FLAG_FILE || resolve(process.env.HOME || "~", ".ica-task-flags");

interface Task {
  id: number;
  title: string;
  subtitle: string;
  points?: number;
  summary: string;
}

let tasks: Task[] = [];
let flagged = new Set<number>();
let currentIndex = 0;
let filterMode: "all" | "flagged" = "all";
let searchQuery = "";

// Parse tasks from markdown file
function parseTasks(raw: string): Task[] {
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
      return { id, title: `Task ${id}`, subtitle, points, summary };
    })
    .sort((a, b) => a.id - b.id);
}

// Load tasks from file
async function loadTasks(): Promise<void> {
  try {
    const raw = await readFile(TASK_FILE, "utf8");
    tasks = parseTasks(raw);
  } catch (error) {
    tasks = [
      {
        id: 1,
        title: "Error",
        subtitle: "Could not load tasks",
        summary: `Failed to read ${TASK_FILE}: ${error}`,
      },
    ];
  }
}

// Load flags from file
async function loadFlags(): Promise<void> {
  try {
    const raw = await readFile(FLAG_FILE, "utf8");
    const ids = raw
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => /^\d+$/.test(line))
      .map(Number);
    flagged = new Set(ids);
  } catch {
    flagged = new Set();
  }
}

// Save flags to file
async function saveFlags(): Promise<void> {
  try {
    const content = Array.from(flagged).sort((a, b) => a - b).join("\n");
    await Bun.write(FLAG_FILE, content + (content ? "\n" : ""));
  } catch (error) {
    console.error("Failed to save flags:", error);
  }
}

// Filter tasks based on current mode and search query
function getFilteredTasks(): Task[] {
  return tasks.filter((task) => {
    if (filterMode === "flagged" && !flagged.has(task.id)) return false;
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase();
    return (
      task.subtitle.toLowerCase().includes(q) ||
      task.summary.toLowerCase().includes(q) ||
      task.title.toLowerCase().includes(q)
    );
  });
}

// Create the TUI
function createUI() {
  const screen = blessed.screen({
    smartCSR: true,
    title: "ICA Istio Lab - Task Navigator",
    fullUnicode: true,
  });

  // Header box
  const header = blessed.box({
    parent: screen,
    top: 0,
    left: 0,
    width: "100%",
    height: 3,
    content: "{center}{bold}ICA Istio Lab - Task Navigator{/bold}{/center}",
    tags: true,
    style: {
      fg: "cyan",
      border: { fg: "cyan" },
    },
    border: { type: "line" },
  });

  // Task list (left pane)
  const taskList = blessed.list({
    parent: screen,
    top: 3,
    left: 0,
    width: "40%",
    height: "100%-6",
    label: " Tasks ",
    keys: true,
    mouse: true,
    style: {
      selected: { bg: "blue", fg: "white", bold: true },
      item: { fg: "white" },
      border: { fg: "cyan" },
    },
    border: { type: "line" },
    tags: true,
    scrollbar: {
      ch: "█",
      style: { fg: "cyan" },
    },
  });

  // Task detail (right pane)
  const taskDetail = blessed.box({
    parent: screen,
    top: 3,
    left: "40%",
    width: "60%",
    height: "100%-6",
    label: " Task Details ",
    content: "",
    tags: true,
    scrollable: true,
    alwaysScroll: true,
    keys: true,
    mouse: true,
    scrollbar: {
      ch: "█",
      style: { fg: "cyan" },
    },
    style: {
      border: { fg: "cyan" },
    },
    border: { type: "line" },
  });

  // Status bar
  const statusBar = blessed.box({
    parent: screen,
    bottom: 2,
    left: 0,
    width: "100%",
    height: 1,
    content: "",
    tags: true,
    style: { fg: "yellow" },
  });

  // Help bar
  const helpBar = blessed.box({
    parent: screen,
    bottom: 0,
    left: 0,
    width: "100%",
    height: 2,
    content:
      "{cyan-fg}[↑/↓/j/k]{/} Navigate | {cyan-fg}[Enter]{/} Select | {cyan-fg}[f]{/} Flag | {cyan-fg}[a]{/} All | {cyan-fg}[F]{/} Flagged | {cyan-fg}[/]{/} Search | {cyan-fg}[q/Esc]{/} Quit",
    tags: true,
    style: {
      border: { fg: "cyan" },
    },
    border: { type: "line" },
  });

  // Search box (hidden by default)
  const searchBox = blessed.textbox({
    parent: screen,
    top: "center",
    left: "center",
    width: "60%",
    height: 3,
    label: " Search ",
    border: { type: "line" },
    style: {
      border: { fg: "yellow" },
      focus: { border: { fg: "green" } },
    },
    hidden: true,
    inputOnFocus: true,
  });

  // Update task list display
  function updateTaskList() {
    const filtered = getFilteredTasks();
    taskList.clearItems();
    
    filtered.forEach((task, idx) => {
      const flag = flagged.has(task.id) ? "{yellow-fg}★{/}" : " ";
      const pts = task.points ?? "?";
      const label = `${flag} {bold}${task.title}{/bold} (${pts}pts)\n   ${task.subtitle}`;
      taskList.addItem(label);
    });

    if (filtered.length === 0) {
      taskList.addItem("{red-fg}No tasks match the current filter{/}");
    }

    // Restore selection
    if (currentIndex >= filtered.length) {
      currentIndex = Math.max(0, filtered.length - 1);
    }
    taskList.select(currentIndex);
    updateStatusBar();
    screen.render();
  }

  // Update task detail display
  function updateTaskDetail() {
    const filtered = getFilteredTasks();
    if (filtered.length === 0) {
      taskDetail.setContent("{center}{red-fg}No tasks to display{/}{/center}");
      screen.render();
      return;
    }

    const task = filtered[currentIndex];
    if (!task) {
      taskDetail.setContent("{center}Select a task to view details{/center}");
      screen.render();
      return;
    }

    const isFlagged = flagged.has(task.id);
    const flagStatus = isFlagged ? "{yellow-fg}★ FLAGGED{/}" : "";
    
    // Format the task body with basic markdown-like rendering
    const body = task.summary
      .split("\n\n")
      .map((para) => {
        // Handle bullet lists
        if (para.match(/^[-*]\s+/m)) {
          return para
            .split("\n")
            .map((line) => line.replace(/^[-*]\s+/, "  • "))
            .join("\n");
        }
        return para;
      })
      .join("\n\n");

    const content = `
{cyan-fg}{bold}${task.subtitle}{/bold}{/}
{gray-fg}${task.title} • ${task.points ?? "?"}pts{/} ${flagStatus}

${"─".repeat(60)}

${body}

${"─".repeat(60)}
{gray-fg}Press 'f' to ${isFlagged ? "unflag" : "flag"} this task{/}
`;

    taskDetail.setContent(content);
    taskDetail.setScrollPerc(0);
    screen.render();
  }

  // Update status bar
  function updateStatusBar() {
    const filtered = getFilteredTasks();
    const flagCount = flagged.size;
    const mode = filterMode === "all" ? "All" : "Flagged";
    const search = searchQuery ? ` | Search: "${searchQuery}"` : "";
    statusBar.setContent(
      `Mode: {cyan-fg}${mode}{/} | Tasks: {cyan-fg}${filtered.length}/${tasks.length}{/} | Flagged: {yellow-fg}${flagCount}{/}${search}`
    );
    screen.render();
  }

  // Toggle flag for current task
  function toggleFlag() {
    const filtered = getFilteredTasks();
    const task = filtered[currentIndex];
    if (!task) return;

    if (flagged.has(task.id)) {
      flagged.delete(task.id);
    } else {
      flagged.add(task.id);
    }
    
    saveFlags().then(() => {
      updateTaskList();
      updateTaskDetail();
    });
  }

  // Event handlers
  taskList.on("select", (item, index) => {
    currentIndex = index;
    updateTaskDetail();
  });

  screen.key(["q", "C-c", "escape"], () => {
    process.exit(0);
  });

  screen.key(["f"], () => {
    toggleFlag();
  });

  screen.key(["a"], () => {
    filterMode = "all";
    currentIndex = 0;
    updateTaskList();
    updateTaskDetail();
  });

  screen.key(["S-f"], () => {
    filterMode = "flagged";
    currentIndex = 0;
    updateTaskList();
    updateTaskDetail();
  });

  screen.key(["/"], () => {
    searchBox.show();
    searchBox.focus();
    screen.render();
  });

  searchBox.on("submit", (value) => {
    searchQuery = value.trim();
    searchBox.clearValue();
    searchBox.hide();
    taskList.focus();
    currentIndex = 0;
    updateTaskList();
    updateTaskDetail();
  });

  searchBox.key(["escape"], () => {
    searchBox.clearValue();
    searchBox.hide();
    taskList.focus();
    screen.render();
  });

  // Navigate with vim keys
  screen.key(["j", "down"], () => {
    taskList.down();
    currentIndex = taskList.selected;
    updateTaskDetail();
  });

  screen.key(["k", "up"], () => {
    taskList.up();
    currentIndex = taskList.selected;
    updateTaskDetail();
  });

  // Scroll detail pane
  screen.key(["pagedown"], () => {
    taskDetail.scroll(taskDetail.height as number || 10);
    screen.render();
  });

  screen.key(["pageup"], () => {
    taskDetail.scroll(-(taskDetail.height as number || 10));
    screen.render();
  });

  taskList.focus();
  return { screen, updateTaskList, updateTaskDetail };
}

// Main entry point
async function main() {
  await loadTasks();
  await loadFlags();
  
  const { updateTaskList, updateTaskDetail } = createUI();
  updateTaskList();
  updateTaskDetail();
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

