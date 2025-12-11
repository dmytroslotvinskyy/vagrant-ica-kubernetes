#!/usr/bin/env bun
import blessed from "blessed";
import type { Widgets } from "blessed";
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
let flagged: Set<number> = new Set<number>();
let currentIndex = 0;
let filterMode: "all" | "flagged" = "all";
let searchQuery = "";

// --- Exam timer config ---
const EXAM_DURATION_MIN = Number.isFinite(parseInt(process.env.EXAM_DURATION_MIN ?? "120", 10))
  ? parseInt(process.env.EXAM_DURATION_MIN ?? "120", 10)
  : 120;
const EXAM_DURATION_SEC = EXAM_DURATION_MIN * 60;
const examStartTime = Date.now();

function getRemainingSeconds(): number {
  const elapsedSec = Math.floor((Date.now() - examStartTime) / 1000);
  return Math.max(0, EXAM_DURATION_SEC - elapsedSec);
}

function formatRemainingTime(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;

  if (h > 0) {
    return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:${s
      .toString()
      .padStart(2, "0")}`;
  }

  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}

// Solutions map for all tasks (hoisted to module scope for reusability)
const TASK_SOLUTIONS: Record<number, string> = {
  1: `{cyan-fg}{bold}Objective:{/bold}{/} Install Istio 1.26.x with demo profile

{white-fg}Step 1: Install Istio with demo profile{/}
{bright-blue-fg}istioctl install --set profile=demo -y{/}

{white-fg}Explanation:{/} The demo profile includes:
  • {green-fg}istiod{/} - Control plane
  • {green-fg}istio-ingressgateway{/} - Ingress gateway
  • All necessary components for testing

{white-fg}Step 2: Wait for istiod to be ready{/}
{bright-blue-fg}kubectl wait -n istio-system deploy/istiod --for=condition=Available --timeout=600s{/}

{white-fg}Step 3: Wait for ingress gateway{/}
{bright-blue-fg}kubectl wait -n istio-system deploy/istio-ingressgateway --for=condition=Available --timeout=600s{/}

{white-fg}Step 4: Verify installation{/}
{bright-blue-fg}istioctl version{/}
{bright-blue-fg}kubectl get deploy -n istio-system{/}

{white-fg}Expected output:{/} Both deployments show AVAILABLE=1`,

  2: `{cyan-fg}{bold}Objective:{/bold}{/} Enable automatic sidecar injection for default namespace

{white-fg}Step 1: Label namespace for injection{/}
{bright-blue-fg}kubectl label ns default istio-injection=enabled --overwrite{/}

{white-fg}Explanation:{/} This label tells Istio to automatically inject
the {green-fg}istio-proxy{/} sidecar into all pods in this namespace.

{white-fg}Step 2: Restart existing deployments{/}
{bright-blue-fg}kubectl -n default rollout restart deploy{/}

{white-fg}Explanation:{/} Existing pods need to be recreated to get
the sidecar injected.

{white-fg}Step 3: Verify sidecar injection{/}
{bright-blue-fg}kubectl get pods -n default{/}
{bright-blue-fg}kubectl describe pod <pod-name> -n default{/}

{white-fg}Expected:{/} Pods should show 2/2 containers (app + istio-proxy)`,

  3: `{cyan-fg}{bold}Objective:{/bold}{/} Route external traffic to httpbin service via Istio Gateway

{white-fg}Step 1: Apply Gateway and VirtualService{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}Gateway httpbin-gw{/bold}{/} - Listens on port 80 for host {bright-green-fg}httpbin.com{/}
  • {cyan-fg}{bold}VirtualService httpbin-vs{/bold}{/} - Routes traffic to {green-fg}httpbin.default.svc.cluster.local:8000{/}

{white-fg}Step 2: Verify resources created{/}
{bright-blue-fg}kubectl get gateway -n default{/}
{bright-blue-fg}kubectl get virtualservice -n default{/}

{white-fg}Step 3: Test the endpoint{/}
{bright-blue-fg}kubectl exec -n default deploy/curl -- curl -H "Host: httpbin.com" http://istio-ingressgateway.istio-system.svc.cluster.local{/}

{white-fg}Key concepts:{/}
  • Gateway defines entry point (ingress gateway)
  • VirtualService defines routing rules
  • Host header must match for routing to work`,

  4: `{cyan-fg}{bold}Objective:{/bold}{/} Expose httpbin using Kubernetes Gateway API

{white-fg}Step 1: Apply Gateway API resources{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}GatewayClass istio{/bold}{/} - Defines Istio as the controller
  • {cyan-fg}{bold}Gateway httpbin-kgw{/bold}{/} - Kubernetes Gateway resource
  • {cyan-fg}{bold}HTTPRoute httpbin-route{/bold}{/} - Routes to httpbin service on port 8000

{white-fg}Step 2: Verify Gateway API resources{/}
{bright-blue-fg}kubectl get gatewayclass{/}
{bright-blue-fg}kubectl get gateway -n default{/}
{bright-blue-fg}kubectl get httproute -n default{/}

{white-fg}Key difference:{/} Gateway API is Kubernetes-native, while
Istio Gateway is Istio-specific. Both achieve similar results.`,

  5: `{cyan-fg}{bold}Objective:{/bold}{/} Split traffic 70% to v1, 30% to v2 in payments namespace

{white-fg}Step 1: Apply DestinationRule and VirtualService{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}DestinationRule payments-dr{/bold}{/} - Defines subsets v1 and v2 based on labels
  • {cyan-fg}{bold}VirtualService payments-vs{/bold}{/} - Routes 70% to subset v1, 30% to subset v2

{white-fg}Step 2: Verify traffic splitting{/}
{bright-blue-fg}kubectl get destinationrule -n payments{/}
{bright-blue-fg}kubectl get virtualservice -n payments{/}

{white-fg}Step 3: Test weighted routing{/}
{bright-blue-fg}for i in {1..10}; do kubectl exec -n payments deploy/curl -- curl -s payments/version; done{/}

{white-fg}Expected:{/} ~70% should show v1, ~30% should show v2`,

  6: `{cyan-fg}{bold}Objective:{/bold}{/} Route /v1 and /v2 to different subsets with URL rewrites

{white-fg}Step 1: Apply VirtualService{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}VirtualService helloworld-match-vs{/bold}{/} with:
    - /v1 → rewrites to /hello, routes to subset v1
    - /v2 → rewrites to /hello, routes to subset v2
    - All other paths → fallback to subset v1

{white-fg}Step 2: Test routing{/}
{bright-blue-fg}kubectl exec -n default deploy/curl -- curl helloworld/v1{/}
{bright-blue-fg}kubectl exec -n default deploy/curl -- curl helloworld/v2{/}
{bright-blue-fg}kubectl exec -n default deploy/curl -- curl helloworld/other{/}

{white-fg}Key concept:{/} URL rewrite changes the path before forwarding to backend`,

  7: `{cyan-fg}{bold}Objective:{/bold}{/} Add timeout and retry logic to payments service

{white-fg}Step 1: Apply updated VirtualService{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this updates:{/}
  • {cyan-fg}{bold}VirtualService payments-vs{/bold}{/} now includes:
    - timeout: 2s (request timeout)
    - retries: 3 attempts
    - perTryTimeout: 1s (timeout per retry)
    - retryOn: 5xx,connect-failure,refused-stream

{white-fg}Step 2: Verify configuration{/}
{bright-blue-fg}kubectl get virtualservice payments-vs -n payments -o yaml{/}

{white-fg}Key concepts:{/}
  • Timeout: Max time to wait for response
  • Retries: Number of retry attempts
  • perTryTimeout: Timeout for each retry attempt`,

  8: `{cyan-fg}{bold}Objective:{/bold}{/} Inject 2s delay on 20% of /v2 traffic

{white-fg}Step 1: Apply VirtualService with fault injection{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}VirtualService helloworld-fault-vs{/bold}{/} with:
    - fault.delay.fixedDelay: 2s
    - fault.delay.percentage.value: 20
    - Applied only to /v2 route

{white-fg}Step 2: Test fault injection{/}
{bright-blue-fg}time kubectl exec -n default deploy/curl -- curl helloworld/v2{/}

{white-fg}Expected:{/} ~20% of requests to /v2 will take 2+ seconds longer

{white-fg}Key concept:{/} Fault injection helps test resilience`,

  9: `{cyan-fg}{bold}Objective:{/bold}{/} Configure circuit breaker for helloworld service

{white-fg}Step 1: Apply DestinationRule with circuit breaker{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}DestinationRule helloworld-cb{/bold}{/} with connection pool limits:
    - http1MaxPendingRequests: 1
    - http2MaxRequests: 1
    - maxRequestsPerConnection: 1

{white-fg}Step 2: Verify configuration{/}
{bright-blue-fg}kubectl get destinationrule helloworld-cb -n default -o yaml{/}

{white-fg}Explanation:{/} Circuit breaker prevents overload by limiting:
  • Max pending HTTP/1.1 requests
  • Max concurrent HTTP/2 requests
  • Max requests per connection

{white-fg}Key concept:{/} Circuit breaker protects backend from overload`,

  10: `{cyan-fg}{bold}Objective:{/bold}{/} Configure outlier detection for fakeservice

{white-fg}Step 1: Apply DestinationRule{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-03-12.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}DestinationRule fakeservice-od{/bold}{/} with outlier detection:
    - consecutive5xxErrors: 1 (eject after 1 error)
    - interval: 5s (check every 5 seconds)
    - baseEjectionTime: 3m (eject for 3 minutes)
    - maxEjectionPercent: 100 (allow 100% ejection)

{white-fg}Step 2: Verify configuration{/}
{bright-blue-fg}kubectl get destinationrule fakeservice-od -n default -o yaml{/}

{white-fg}Key concept:{/} Outlier detection removes unhealthy endpoints`,

  11: `{cyan-fg}{bold}Objective:{/bold}{/} Deploy Prometheus for metrics collection

{white-fg}Step 1: Apply Prometheus deployment{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-11-16.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}Deployment prometheus{/bold}{/} in {magenta-fg}{bold}istio-system{/bold}{/} namespace

{white-fg}Step 2: Verify Prometheus is running{/}
{bright-blue-fg}kubectl get deploy prometheus -n istio-system{/}
{bright-blue-fg}kubectl get pods -n istio-system -l app=prometheus{/}

{white-fg}Step 3: Access Prometheus UI (if port-forward enabled){/}
{bright-blue-fg}kubectl port-forward -n istio-system svc/prometheus 9090:9090{/}

{white-fg}Key concept:{/} Prometheus scrapes metrics from Istio components`,

  12: `{cyan-fg}{bold}Objective:{/bold}{/} Deploy Kiali and enable injection for bookinfo

{white-fg}Step 1: Apply Kiali deployment{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-11-16.yaml{/}

{white-fg}Step 2: Label bookinfo namespace for injection{/}
{bright-blue-fg}kubectl label ns bookinfo istio-injection=enabled{/}

{white-fg}Explanation:{/} This enables automatic sidecar injection
for all pods in the {magenta-fg}{bold}bookinfo{/bold}{/} namespace.

{white-fg}Step 3: Verify Kiali deployment{/}
{bright-blue-fg}kubectl get deploy kiali -n istio-system{/}
{bright-blue-fg}kubectl get pods -n istio-system -l app=kiali{/}

{white-fg}Step 4: Verify namespace label{/}
{bright-blue-fg}kubectl get ns bookinfo --show-labels{/}

{white-fg}Key concept:{/} Kiali provides service mesh visualization`,

  13: `{cyan-fg}{bold}Objective:{/bold}{/} Deploy Jaeger and configure 100% trace sampling

{white-fg}Step 1: Apply Jaeger deployment{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-11-16.yaml{/}

{white-fg}Step 2: Apply Telemetry resource for 100% sampling{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-13-16.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}Deployment jaeger{/bold}{/} in {magenta-fg}{bold}istio-system{/bold}{/}
  • {cyan-fg}{bold}Telemetry mesh-default{/bold}{/} with randomSamplingPercentage: 100

{white-fg}Step 3: Verify Jaeger{/}
{bright-blue-fg}kubectl get deploy jaeger -n istio-system{/}
{bright-blue-fg}kubectl get telemetry -n istio-system{/}

{white-fg}Step 4: Verify sampling{/}
{bright-blue-fg}kubectl get telemetry mesh-default -n istio-system -o yaml{/}

{white-fg}Key concept:{/} 100% sampling captures all traces (use carefully in production)`,

  14: `{cyan-fg}{bold}Objective:{/bold}{/} Enforce STRICT mTLS with port-level override

{white-fg}Step 1: Apply PeerAuthentication resources{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-13-16.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}PeerAuthentication default-strict{/bold}{/}:
    - Enforces STRICT mTLS for all pods in {magenta-fg}{bold}default{/bold}{/} namespace
  • {cyan-fg}{bold}PeerAuthentication httpbin-port-permissive{/bold}{/}:
    - Selector matches {green-fg}app: httpbin{/}
    - Port 8000 allows PERMISSIVE mode (non-mTLS allowed)

{white-fg}Step 2: Verify PeerAuthentication{/}
{bright-blue-fg}kubectl get peerauthentication -n default{/}
{bright-blue-fg}kubectl get peerauthentication default-strict -n default -o yaml{/}
{bright-blue-fg}kubectl get peerauthentication httpbin-port-permissive -n default -o yaml{/}

{white-fg}Key concepts:{/}
  • STRICT: Only mTLS traffic allowed
  • PERMISSIVE: Both mTLS and plain text allowed
  • Port-level override: More specific policy wins`,

  15: `{cyan-fg}{bold}Objective:{/bold}{/} Deny all by default, allow only curl SA POST to httpbin

{white-fg}Step 1: Apply AuthorizationPolicy resources{/}
{bright-blue-fg}kubectl apply -f /vagrant/manifests/task-13-16.yaml{/}

{white-fg}What this creates:{/}
  • {cyan-fg}{bold}AuthorizationPolicy allow-nothing{/bold}{/}:
    - Empty spec = deny all traffic by default
  • {cyan-fg}{bold}AuthorizationPolicy curl-to-httpbin-post-only{/bold}{/}:
    - Selector: {green-fg}app: httpbin{/}
    - Action: ALLOW
    - Source: {green-fg}cluster.local/ns/default/sa/curl{/}
    - Method: POST only

{white-fg}Step 2: Verify policies{/}
{bright-blue-fg}kubectl get authorizationpolicy -n default{/}
{bright-blue-fg}kubectl get authorizationpolicy curl-to-httpbin-post-only -n default -o yaml{/}

{white-fg}Step 3: Test authorization{/}
{bright-blue-fg}# This should work (POST from curl SA){/}
{bright-blue-fg}kubectl exec -n default deploy/curl -- curl -X POST httpbin/post{/}
{bright-blue-fg}# This should fail (GET not allowed){/}
{bright-blue-fg}kubectl exec -n default deploy/curl -- curl httpbin/get{/}

{white-fg}Key concept:{/} AuthorizationPolicy controls who can do what`,

  16: `{cyan-fg}{bold}Objective:{/bold}{/} Create revision tag and apply to swagger namespace

{white-fg}Step 1: Create revision tag{/}
{bright-blue-fg}istioctl tag set latest --revision default --overwrite{/}

{white-fg}Explanation:{/} Creates a tag "latest" pointing to the
"default" Istio revision. Tags are aliases for revisions.

{white-fg}Step 2: Label swagger namespace to use the tag{/}
{bright-blue-fg}kubectl label ns swagger istio.io/rev=latest --overwrite{/}

{white-fg}Explanation:{/} This tells Istio to inject sidecars from
the "latest" revision (which points to "default").

{white-fg}Step 3: Verify tag exists{/}
{bright-blue-fg}istioctl tag list{/}

{white-fg}Step 4: Verify namespace label{/}
{bright-blue-fg}kubectl get ns swagger --show-labels{/}

{white-fg}Step 5: Restart pods to get new sidecars{/}
{bright-blue-fg}kubectl rollout restart deploy -n swagger{/}

{white-fg}Key concepts:{/}
  • Revision: Specific Istio control plane version
  • Tag: Alias/pointer to a revision
  • istio.io/rev label: Tells which revision to use for injection`
};

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
function createUI(): {
  screen: Widgets.Screen;
  updateTaskList: () => void;
  updateTaskDetail: () => void;
  updateStatusBar: () => void;
} {
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
      selected: { bg: "black", fg: "cyan", bold: true },
      item: { fg: "cyan" },
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
    style: { fg: "cyan" },
  });

  // Solutions box (hidden by default)
  const solutionsBox = blessed.box({
    parent: screen,
    top: "center",
    left: "center",
    width: "80%",
    height: "70%",
    label: " Solution ",
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
    hidden: true,
  });

  // Help bar
  const helpBar = blessed.box({
    parent: screen,
    bottom: 0,
    left: 0,
    width: "100%",
    height: 2,
    content:
      "{cyan-fg}[↑/↓/j/k]{/} Navigate | {cyan-fg}[Enter]{/} Select | {cyan-fg}[f]{/} Flag | {cyan-fg}[F]{/} Filter | {cyan-fg}[s]{/} Solution | {cyan-fg}[/]{/} Search | {cyan-fg}[q/Esc]{/} Quit",
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
      border: { fg: "cyan" },
      focus: { border: { fg: "cyan" } },
    },
    hidden: true,
    inputOnFocus: true,
  });

  // Update task list display
  function updateTaskList() {
    const filtered = getFilteredTasks();
    taskList.clearItems();
    
    filtered.forEach((task, idx) => {
      const flag = flagged.has(task.id) ? "{cyan-fg}★{/}" : " ";
      const pts = task.points ?? "?";
      const label = `${flag} {cyan-fg}{bold}${task.title}{/bold}{/} (${pts}pts)\n   ${task.subtitle}`;
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

  // Highlight important terms in task content
  function highlightContent(text: string): string {
    // First, highlight backtick-wrapped terms with different colors based on type
    text = text.replace(/`([^`]+)`/g, (_match, name) => `{cyan-fg}\`${name}\`{/}`);

    // Highlight standalone namespace mentions
    text = text.replace(/\b(namespace|Namespace)\s+`?([a-z0-9-]+)`?/gi, (_match, keyword, ns) => {
      return `{cyan-fg}${keyword} ${ns || ''}{/}`;
    });

    // Highlight commands (kubectl, istioctl, curl) - full line
    text = text.replace(/^(kubectl|istioctl|curl)\s+([^\n]+)/gm, (_match, cmd, args) => {
      return `{cyan-fg}{bold}${cmd}{/bold} ${args}{/}`;
    });

    // Instruction lines
    text = text.replace(/^(Test|You can|Confirm|Verify|Run|Create|Apply|Update|Ensure|Deploy|Install|Label|Expose|Add|Inject|Configure)\b/gmi, (match) => {
      return `{cyan-fg}${match}{/}`;
    });

    // Ports, percentages, durations, hostnames all in cyan
    text = text.replace(/\b(port|Port|on port)\s+(\d+)/gi, (_m, keyword, port) => {
      return `{cyan-fg}${keyword} ${port}{/}`;
    });
    text = text.replace(/\b(\d+)%/g, `{cyan-fg}$1%{/}`);
    text = text.replace(/\b(\d+[sm])\b/g, `{cyan-fg}$1{/}`);
    text = text.replace(/\b([a-z0-9-]+\.(com|local|svc\.cluster\.local))\b/gi, (match) => {
      return `{cyan-fg}${match}{/}`;
    });

    return text;
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
    const flagStatus = isFlagged ? " {cyan-fg}★ FLAGGED{/}" : "";
    const taskNumber = String(task.id).padStart(2, '0');
    
    // Format the task body with enhanced highlighting
    let body = task.summary;
    
    // Handle numbered steps
    body = body.replace(/^(\d+\.)\s+/gm, `{cyan-fg}$1{/} `);
    
    // Handle bullet lists
    body = body.split("\n\n")
      .map((para) => {
        if (para.match(/^[-*]\s+/m)) {
          return para
            .split("\n")
            .map((line) => line.replace(/^[-*]\s+/, `  {cyan-fg}•{/} `))
            .join("\n");
        }
        return para;
      })
      .join("\n\n");

    // Apply highlighting
    body = highlightContent(body);

    // Format content with task number at top
    const content = `
{cyan-fg}{bold}Task ${taskNumber} (${task.points ?? "?"} pts){/bold}{/}${flagStatus}
{cyan-fg}{bold}${task.subtitle}{/bold}{/}

${"─".repeat(60)}

{cyan-fg}${body}{/}

${"─".repeat(60)}
{cyan-fg}Press 'f' to ${isFlagged ? "unflag" : "flag"} | Press 's' for solution{/}
{cyan-fg}💡 Copy: Shift+Mouse or Ctrl+b [ then v(select) y(copy){/}
`;

    taskDetail.setContent(content);
    taskDetail.setScrollPerc(0);
    screen.render();
  }

  // Show solution for current task
  function showSolution() {
    const filtered = getFilteredTasks();
    const task = filtered[currentIndex];
    if (!task) return;

    const taskId = typeof task.id === 'string' ? parseInt(task.id) : task.id;
    const solutionRaw = TASK_SOLUTIONS[taskId] || "No solution available for this task.";
    // Strip existing color tags to keep a monochrome azure look
    const solution = solutionRaw.replace(/\{[^}]+\}/g, "");
    
    solutionsBox.setContent(
      `${solution}\n\n` +
      `{cyan-fg}─${"─".repeat(58)}─{/}\n\n` +
      `{cyan-fg}How to copy commands:{/}\n` +
      `{cyan-fg}1. Use tmux copy mode: Ctrl+b then [\n` +
      `2. Navigate with arrow keys\n` +
      `3. Press Space to start selection\n` +
      `4. Move to end and press Enter to copy\n` +
      `5. Paste with Ctrl+b then ]{/}\n\n` +
      `{cyan-fg}Or view in file:{/}\n` +
      `{cyan-fg}cat /vagrant/TASK-SOLUTIONS.txt{/}\n\n` +
      `{cyan-fg}Press 'Esc' or 'q' to close | Use arrow keys to scroll{/}`
    );
    solutionsBox.setScrollPerc(0);
    solutionsBox.show();
    solutionsBox.focus();
    screen.render();
  }

  // Update status bar
  function updateStatusBar() {
    const filtered = getFilteredTasks();
    const currentTask = filtered[currentIndex];
    const currentTaskDisplay = currentTask ? `Task ${String(currentTask.id).padStart(2, '0')}` : '--';
    const flagCount = flagged.size;
    const mode = filterMode === "all" ? "All" : "Flagged";
    const search = searchQuery ? ` | Search: "${searchQuery}"` : "";
    const position = filtered.length > 0 ? `${currentIndex + 1}/${filtered.length}` : '0/0';
    const remainingSec = getRemainingSeconds();
    const timeStr = formatRemainingTime(remainingSec);
    const timeLabel = remainingSec === 0 ? "{cyan-fg}TIME UP{/}" : `{cyan-fg}${timeStr}{/}`;
    statusBar.setContent(
      `{cyan-fg}${currentTaskDisplay}{/} (${position}) | Mode: {cyan-fg}${mode}{/} | Total: {cyan-fg}${tasks.length}{/} | Flagged: {cyan-fg}${flagCount}{/}${search} | Time left: ${timeLabel}`
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
  taskList.on("select", (item: any, index: number) => {
    currentIndex = index;
    updateTaskDetail();
  });

  screen.key(["q", "C-c", "escape"], () => {
    process.exit(0);
  });

  screen.key(["f"], () => {
    if (solutionsBox.hidden) {
      toggleFlag();
    }
  });

  screen.key(["s"], () => {
    if (solutionsBox.hidden) {
      showSolution();
    }
  });

  solutionsBox.key(["escape", "q"], () => {
    solutionsBox.hide();
    taskList.focus();
    screen.render();
  });

  screen.key(["S-f"], () => {
    if (solutionsBox.hidden) {
      // Toggle between all and flagged modes
      filterMode = filterMode === "all" ? "flagged" : "all";
      currentIndex = 0;
      updateTaskList();
      updateTaskDetail();
    }
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
    const filtered = getFilteredTasks();
    if (currentIndex < filtered.length - 1) {
      currentIndex++;
      taskList.select(currentIndex);
      updateTaskDetail();
    }
  });

  screen.key(["k", "up"], () => {
    if (currentIndex > 0) {
      currentIndex--;
      taskList.select(currentIndex);
      updateTaskDetail();
    }
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
  return { screen, updateTaskList, updateTaskDetail, updateStatusBar };
}

// Main entry point
async function main(): Promise<void> {
  await loadTasks();
  await loadFlags();
  
  const { updateTaskList, updateTaskDetail, updateStatusBar } = createUI();
  updateTaskList();
  updateTaskDetail();

  // Kick off the countdown ticker
  setInterval(() => {
    updateStatusBar();
  }, 1000);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

