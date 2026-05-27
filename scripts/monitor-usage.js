import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const relaySsh = process.env.PET_Y_RELAY_SSH || "root@47.99.98.43";
const analyticsPath = process.env.PET_Y_REMOTE_ANALYTICS_PATH || "/opt/pet-y/data/analytics.jsonl";
const relayStatePath = process.env.PET_Y_REMOTE_STATE_PATH || "/opt/pet-y/data/relay-state.json";
const snapshotPath = process.env.PET_Y_USAGE_SNAPSHOT_PATH || path.join("data", "usage-monitor-snapshots.jsonl");
const timeZone = "Asia/Shanghai";

function remoteRead() {
  const script = [
    "curl -fsS http://127.0.0.1:8787/api/admin/stats",
    "printf '\\n---PET_Y_ANALYTICS---\\n'",
    `cat ${shellQuote(analyticsPath)} 2>/dev/null || true`,
    "printf '\\n---PET_Y_RELAY_STATE---\\n'",
    `cat ${shellQuote(relayStatePath)} 2>/dev/null || true`
  ].join(" && ");
  const result = spawnSync("ssh", ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8", relaySsh, script], {
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024
  });
  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || "无法读取 Relay 统计").trim());
  }
  const [statsText, remainder = ""] = result.stdout.split("\n---PET_Y_ANALYTICS---\n");
  const [analyticsText = "", relayStateText = ""] = remainder.split("\n---PET_Y_RELAY_STATE---\n");
  return {
    stats: JSON.parse(statsText),
    events: analyticsText.split("\n").filter(Boolean).map((line) => JSON.parse(line)),
    relayState: relayStateText.trim() ? JSON.parse(relayStateText) : null
  };
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

function dayKey(date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(date);
  const part = Object.fromEntries(parts.map((item) => [item.type, item.value]));
  return `${part.year}-${part.month}-${part.day}`;
}

function addDays(key, offset) {
  const [year, month, day] = key.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day + offset, 12));
  return dayKey(date);
}

function userHashes(event) {
  return ["user_hash", "owner_hash", "host_hash", "actor_hash"]
    .map((key) => event[key])
    .filter(Boolean);
}

function inc(map, key) {
  map[key] = (map[key] || 0) + 1;
}

function analyze(stats, events) {
  const now = new Date(stats.now || Date.now());
  const today = dayKey(now);
  const yesterday = addDays(today, -1);
  const dayUsers = new Map();
  const firstSeen = new Map();
  const lastSeen = new Map();
  const counters24h = {};
  const eventTypes24h = {};
  const last24hCutoff = now.getTime() - 24 * 60 * 60 * 1000;
  const last7dCutoff = now.getTime() - 7 * 24 * 60 * 60 * 1000;
  const active24h = new Set();
  const active7d = new Set();
  let events24h = 0;

  for (const event of events) {
    const at = new Date(event.at);
    if (Number.isNaN(at.getTime())) continue;
    const day = dayKey(at);
    if (!dayUsers.has(day)) dayUsers.set(day, new Set());
    for (const user of userHashes(event)) {
      dayUsers.get(day).add(user);
      if (!firstSeen.has(user) || day < firstSeen.get(user)) firstSeen.set(user, day);
      if (!lastSeen.has(user) || day > lastSeen.get(user)) lastSeen.set(user, day);
      if (at.getTime() >= last24hCutoff) active24h.add(user);
      if (at.getTime() >= last7dCutoff) active7d.add(user);
    }
    if (at.getTime() >= last24hCutoff) {
      events24h += 1;
      inc(counters24h, event.name);
      if (event.event_type) inc(eventTypes24h, event.event_type);
    }
  }

  const todayUsers = dayUsers.get(today) || new Set();
  const yesterdayUsers = dayUsers.get(yesterday) || new Set();
  const newToday = [...firstSeen.values()].filter((day) => day === today).length;
  const newYesterdayUsers = [...firstSeen.entries()]
    .filter(([, day]) => day === yesterday)
    .map(([user]) => user);
  const retainedFromYesterday = newYesterdayUsers.filter((user) => todayUsers.has(user)).length;
  const returningToday = [...todayUsers].filter((user) => firstSeen.get(user) < today).length;

  return {
    generated_at: now.toISOString(),
    today,
    yesterday,
    runtime: stats.runtime,
    persisted: stats.persisted,
    counters24h,
    eventTypes24h,
    events24h,
    active24h: active24h.size,
    active7d: active7d.size,
    activeToday: todayUsers.size,
    activeYesterday: yesterdayUsers.size,
    newToday,
    newYesterday: newYesterdayUsers.length,
    retainedFromYesterday,
    returningToday
  };
}

function previousSnapshot() {
  if (!fs.existsSync(snapshotPath)) return null;
  const lines = fs.readFileSync(snapshotPath, "utf8").trim().split("\n").filter(Boolean);
  if (!lines.length) return null;
  return JSON.parse(lines.at(-1));
}

function appendSnapshot(snapshot) {
  fs.mkdirSync(path.dirname(snapshotPath), { recursive: true });
  fs.appendFileSync(snapshotPath, `${JSON.stringify(snapshot)}\n`);
}

function delta(current, previous, keyPath) {
  const read = (source) => keyPath.split(".").reduce((value, key) => value?.[key], source) ?? 0;
  if (!previous) return null;
  return read(current) - read(previous);
}

function fmtDelta(value) {
  if (value === null) return "首次记录";
  return value >= 0 ? `+${value}` : String(value);
}

function topEntries(map, limit = 5) {
  return Object.entries(map || {})
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([key, value]) => `${key} ${value}`)
    .join("，") || "暂无";
}

function formatTable(headers, rows) {
  const widths = headers.map((header, index) =>
    Math.max(header.length, ...rows.map((row) => String(row[index] ?? "").length))
  );
  const formatRow = (row) => row.map((cell, index) => String(cell ?? "").padEnd(widths[index], " ")).join(" | ");
  return [
    formatRow(headers),
    widths.map((width) => "-".repeat(width)).join("-|-"),
    ...rows.map(formatRow)
  ].join("\n");
}

function petDetailRows(relayState) {
  const profiles = relayState?.profiles || [];
  const usersById = new Map((relayState?.users || []).map((user) => [user.user_id, user]));
  return profiles
    .map((profile) => {
      const owner = usersById.get(profile.owner_user_id);
      return [
        profile.name || "-",
        owner?.display_name || profile.owner_user_id || "-",
        profile.pet_id || "-",
        Object.keys(profile.animation_states || {}).length,
        (profile.interaction_capabilities || []).length,
        profile.updated_at ? profile.updated_at.slice(0, 19).replace("T", " ") : "-"
      ];
    })
    .sort((a, b) => a[0].localeCompare(b[0], "zh-Hans-CN"));
}

function dailyTaskRows(events, today) {
  const tasks = [
    { key: "profile_registered", label: "注册宠物" },
    { key: "invite_created", label: "创建邀请" },
    { key: "friend_added", label: "好友绑定" },
    { key: "visit_requested", label: "发起串门请求" },
    { key: "visit_started", label: "开始串门" },
    { key: "visit_event", label: "发生互动" }
  ];
  const rows = [];
  for (const task of tasks) {
    const matched = events.filter((event) => event.name === task.key && dayKey(new Date(event.at)) === today);
    const users = new Set();
    const pets = new Set();
    for (const event of matched) {
      for (const user of userHashes(event)) users.add(user);
      if (event.pet_hash) pets.add(event.pet_hash);
    }
    rows.push([task.label, matched.length, users.size, pets.size]);
  }
  return rows;
}

function report(current, previous, relayState, events) {
  const petRows = petDetailRows(relayState);
  const taskRows = dailyTaskRows(events, current.today);
  const lines = [
    `Pet Y 使用监控（${current.today}，北京时间）`,
    "",
    `当前在线：${current.runtime.online_users}，活跃串门：${current.runtime.active_visits}`,
    `累计匿名用户：${current.persisted.unique_users}（较上次 ${fmtDelta(delta(current, previous, "persisted.unique_users"))}）`,
    `累计宠物：${current.persisted.unique_pets}（较上次 ${fmtDelta(delta(current, previous, "persisted.unique_pets"))}）`,
    `累计好友绑定：${current.persisted.counters.friend_added || 0}（较上次 ${fmtDelta(delta(current, previous, "persisted.counters.friend_added"))}）`,
    `累计串门开始：${current.persisted.counters.visit_started || 0}（较上次 ${fmtDelta(delta(current, previous, "persisted.counters.visit_started"))}）`,
    "",
    `过去 24 小时：活跃用户 ${current.active24h}，事件 ${current.events24h}，互动 ${current.counters24h.visit_event || 0}`,
    `今日：新增用户 ${current.newToday}，活跃用户 ${current.activeToday}，老用户回访 ${current.returningToday}`,
    `昨日新增今日回访：${current.retainedFromYesterday}/${current.newYesterday}`,
    `近 7 天活跃用户：${current.active7d}`,
    "",
    "宠物明细：",
    petRows.length
      ? formatTable(["宠物名", "主人", "pet_id", "动画数", "互动能力", "最近更新时间"], petRows)
      : "暂无",
    "",
    "今日任务明细：",
    formatTable(["任务", "次数", "涉及用户", "涉及宠物"], taskRows),
    "",
    `24 小时主要事件：${topEntries(current.counters24h)}`,
    `24 小时互动类型：${topEntries(current.eventTypes24h)}`,
    `最后事件时间：${current.persisted.last_event_at || "暂无"}`
  ];
  return lines.join("\n");
}

const { stats, events, relayState } = remoteRead();
const current = analyze(stats, events);
const previous = previousSnapshot();
appendSnapshot(current);
console.log(report(current, previous, relayState, events));
