const state = {
  tasks: [],
  filtered: [],
  activeId: null,
  filter: "all",
  query: "",
  flagged: new Set(JSON.parse(localStorage.getItem("icaTaskFlags") ?? "[]")),
};

const selectors = {
  list: document.getElementById("taskList"),
  detail: document.getElementById("taskDetail"),
  search: document.getElementById("searchInput"),
  filterAll: document.getElementById("filterAll"),
  filterFlagged: document.getElementById("filterFlagged"),
  countLabel: document.getElementById("taskCountLabel"),
};

function saveFlags() {
  localStorage.setItem("icaTaskFlags", JSON.stringify(Array.from(state.flagged)));
}

function setActive(id) {
  state.activeId = id;
  renderTasks();
  renderDetail();
}

function toggleFlag(id) {
  if (state.flagged.has(id)) {
    state.flagged.delete(id);
  } else {
    state.flagged.add(id);
  }
  saveFlags();
  renderTasks();
  renderDetail();
}

function applyFilters() {
  const query = state.query.toLowerCase();
  state.filtered = state.tasks.filter((task) => {
    if (state.filter === "flagged" && !state.flagged.has(task.id)) {
      return false;
    }
    if (!query) return true;
    return (
      task.subtitle.toLowerCase().includes(query) ||
      task.summary.toLowerCase().includes(query)
    );
  });
}

function createTaskItem(task) {
  const li = document.createElement("li");
  li.className = "task-item";
  if (task.id === state.activeId) li.classList.add("active");
  if (state.flagged.has(task.id)) li.classList.add("flagged");

  const button = document.createElement("button");
  button.type = "button";
  button.innerHTML = `
    <span class="flag" aria-hidden="true">★</span>
    <div class="task-meta">
      <strong>${task.title}</strong>
      <span>${task.subtitle}</span>
    </div>
    <span class="pill">${task.points ?? "?"} pts</span>
  `;
  button.addEventListener("click", () => setActive(task.id));
  li.appendChild(button);
  return li;
}

function renderTasks() {
  applyFilters();
  selectors.list.innerHTML = "";
  state.filtered.forEach((task) => {
    selectors.list.appendChild(createTaskItem(task));
  });
  selectors.countLabel.textContent = `${state.filtered.length} tasks`;
}

function renderDetail() {
  selectors.detail.innerHTML = "";
  const task = state.tasks.find((t) => t.id === state.activeId);
  if (!task) {
    selectors.detail.innerHTML = `<div class="placeholder"><h2>Select a task</h2><p>Choose an item on the left to see all requirements.</p></div>`;
    return;
  }

  const header = document.createElement("header");
  header.innerHTML = `
    <div>
      <p class="eyebrow">Task ${task.id}</p>
      <h2>${task.subtitle}</h2>
    </div>
    <div class="actions">
      <span class="tag">${task.points ?? "?"} pts</span>
      <button class="flag-toggle ${state.flagged.has(task.id) ? "active" : ""}">${state.flagged.has(task.id) ? "Flagged" : "Flag task"}</button>
    </div>
  `;
  header.querySelector(".flag-toggle").addEventListener("click", () => toggleFlag(task.id));

  const body = document.createElement("div");
  body.className = "task-body";
  body.innerHTML = task.html;

  const container = document.createElement("div");
  container.appendChild(header);
  container.appendChild(body);
  selectors.detail.appendChild(container);
}

function bindControls() {
  selectors.search.addEventListener("input", (event) => {
    state.query = event.target.value;
    renderTasks();
  });

  const toggleFilter = (filter) => {
    state.filter = filter;
    selectors.filterAll.classList.toggle("chip--active", filter === "all");
    selectors.filterFlagged.classList.toggle("chip--active", filter === "flagged");
    renderTasks();
  };

  selectors.filterAll.addEventListener("click", () => toggleFilter("all"));
  selectors.filterFlagged.addEventListener("click", () => toggleFilter("flagged"));
}

async function bootstrap() {
  try {
    const response = await fetch("/api/tasks");
    if (!response.ok) throw new Error("Unable to load tasks");
    const payload = await response.json();
    state.tasks = payload.tasks;
    if (state.tasks.length) {
      state.activeId = state.tasks[0].id;
    }
    bindControls();
    renderTasks();
    renderDetail();
  } catch (error) {
    selectors.detail.innerHTML = `<div class="placeholder"><h2>Unable to load tasks</h2><p>${error}</p></div>`;
  }
}

bootstrap();
