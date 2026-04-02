import process from "node:process";

const args = process.argv.slice(2);
const urls = [];
const staticHeaders = {};
const sessionIdsByUrl = new Map();
let activeUrl = "";

function expandEnvironment(value) {
  return value.replace(/\$\{([A-Z0-9_]+)\}/g, (_, key) => process.env[key] || "");
}

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--url") {
    const candidate = expandEnvironment(args[i + 1] || "").trim();
    if (candidate) {
      urls.push(candidate);
    }
    i += 1;
    continue;
  }
  if (arg === "--header") {
    const raw = expandEnvironment(args[i + 1] || "");
    const splitIndex = raw.indexOf("=");
    if (splitIndex <= 0) {
      throw new Error(`invalid --header value: ${raw}`);
    }
    staticHeaders[raw.slice(0, splitIndex)] = raw.slice(splitIndex + 1);
    i += 1;
  }
}

if (urls.length === 0) {
  throw new Error("missing required --url");
}

let stdinBuffer = "";
let drainInFlight = false;
let drainRequested = false;

function writeMessage(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function parseSseMessages(text) {
  const blocks = text.split(/\r?\n\r?\n/);
  const messages = [];
  for (const block of blocks) {
    const dataLines = [];
    for (const line of block.split(/\r?\n/)) {
      if (line.startsWith("data:")) {
        dataLines.push(line.slice(5).trimStart());
      }
    }
    if (dataLines.length === 0) {
      continue;
    }
    const payload = dataLines.join("\n");
    if (payload === "[DONE]") {
      continue;
    }
    messages.push(JSON.parse(payload));
  }
  return messages;
}

async function forwardMessageToUrl(url, message) {
  const headers = {
    "accept": "application/json, text/event-stream",
    "content-type": "application/json",
    ...staticHeaders
  };
  const sessionId = sessionIdsByUrl.get(url) || "";
  if (sessionId) {
    headers["mcp-session-id"] = sessionId;
  }

  const response = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(message),
    signal: AbortSignal.timeout(30000)
  });

  if (!response.ok) {
    throw new Error(`remote MCP request failed with HTTP ${response.status}`);
  }

  const newSessionId = response.headers.get("mcp-session-id");
  if (newSessionId) {
    sessionIdsByUrl.set(url, newSessionId);
  }

  const contentType = response.headers.get("content-type") || "";
  const bodyText = await response.text();
  if (!bodyText.trim()) {
    return;
  }

  if (contentType.includes("text/event-stream")) {
    for (const payload of parseSseMessages(bodyText)) {
      writeMessage(payload);
    }
    return;
  }

  const payload = JSON.parse(bodyText);
  if (Array.isArray(payload)) {
    for (const item of payload) {
      writeMessage(item);
    }
    return;
  }
  writeMessage(payload);
}

async function forwardMessage(message) {
  const candidateUrls = activeUrl
    ? [activeUrl, ...urls.filter((candidate) => candidate !== activeUrl)]
    : urls;
  let lastError = null;

  for (const candidateUrl of candidateUrls) {
    try {
      await forwardMessageToUrl(candidateUrl, message);
      activeUrl = candidateUrl;
      return;
    } catch (error) {
      sessionIdsByUrl.delete(candidateUrl);
      if (activeUrl === candidateUrl) {
        activeUrl = "";
      }
      lastError = error;
    }
  }

  throw lastError || new Error("no reachable MCP endpoint configured");
}

async function drainBuffer() {
  while (true) {
    const newlineIndex = stdinBuffer.indexOf("\n");
    if (newlineIndex === -1) {
      return;
    }

    const rawLine = stdinBuffer.slice(0, newlineIndex);
    stdinBuffer = stdinBuffer.slice(newlineIndex + 1);
    const payload = rawLine.trim();
    if (!payload) {
      continue;
    }
    await forwardMessage(JSON.parse(payload));
  }
}

async function scheduleDrain() {
  if (drainInFlight) {
    drainRequested = true;
    return;
  }

  drainInFlight = true;
  try {
    do {
      drainRequested = false;
      await drainBuffer();
    } while (drainRequested);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  } finally {
    drainInFlight = false;
  }
}

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  stdinBuffer += chunk;
  void scheduleDrain();
});
