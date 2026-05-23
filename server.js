import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, "public");
const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || "127.0.0.1";

const users = new Map([
  [
    "alice",
    {
      user_id: "alice",
      display_name: "Alice",
      pet_id: "pet_momo",
      host_rules: {
        allow_friend_auto_visit: true,
        allow_bubble_text: true,
        allow_sound: false,
        allow_record_interactions: true,
        allow_pet_to_pet_interactions: true,
        allow_gifts_to_return: true,
        max_visit_minutes: 10,
        movement_policy: "free_roam",
        blocked_pet_ids: [],
        muted_pet_ids: []
      }
    }
  ],
  [
    "bob",
    {
      user_id: "bob",
      display_name: "Bob",
      pet_id: "pet_yuzu",
      host_rules: {
        allow_friend_auto_visit: true,
        allow_bubble_text: true,
        allow_sound: false,
        allow_record_interactions: true,
        allow_pet_to_pet_interactions: true,
        allow_gifts_to_return: true,
        max_visit_minutes: 10,
        movement_policy: "free_roam",
        blocked_pet_ids: [],
        muted_pet_ids: []
      }
    }
  ]
]);

const friendships = new Set(["alice:bob", "bob:alice"]);
const profiles = new Map();
const visits = new Map();
const invites = new Map();
const eventStreams = new Map();
const eventMailboxes = new Map();
const runtimePresence = new Map();
let eventSequence = 0;
const onlineTimeoutMs = 6_000;

function sendJson(res, status, data) {
  const body = JSON.stringify(data, null, 2);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 5_000_000) {
        reject(new Error("Request body too large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(error);
      }
    });
  });
}

function friendshipKey(a, b) {
  return `${a}:${b}`;
}

function areFriends(a, b) {
  return friendships.has(friendshipKey(a, b));
}

function markUserOnline(userId) {
  runtimePresence.set(userId, Date.now());
}

function isUserOnline(userId) {
  if (eventStreams.get(userId)?.size > 0) return true;
  const lastSeen = runtimePresence.get(userId);
  return Boolean(lastSeen && Date.now() - lastSeen < onlineTimeoutMs);
}

function friendSummaries(userId) {
  return [...users.values()]
    .filter((user) => user.user_id !== userId && areFriends(userId, user.user_id))
    .map((user) => ({
      user_id: user.user_id,
      display_name: user.display_name,
      pet_id: user.pet_id,
      online: isUserOnline(user.user_id),
      last_seen_at: runtimePresence.has(user.user_id)
        ? new Date(runtimePresence.get(user.user_id)).toISOString()
        : null
    }));
}

function defaultHostRules() {
  return {
    allow_friend_auto_visit: true,
    allow_bubble_text: true,
    allow_sound: false,
    allow_record_interactions: true,
    allow_pet_to_pet_interactions: true,
    allow_gifts_to_return: true,
    max_visit_minutes: 10,
    movement_policy: "free_roam",
    blocked_pet_ids: [],
    muted_pet_ids: []
  };
}

function ensureUser(userId, displayName = userId) {
  if (!users.has(userId)) {
    users.set(userId, {
      user_id: userId,
      display_name: displayName,
      pet_id: "",
      host_rules: defaultHostRules()
    });
  }
  const user = users.get(userId);
  if (displayName && user.display_name === user.user_id) {
    user.display_name = displayName;
  }
  return user;
}

function addFriendship(a, b) {
  friendships.add(friendshipKey(a, b));
  friendships.add(friendshipKey(b, a));
}

function emitTo(userId, type, payload) {
  const event = {
    id: ++eventSequence,
    type,
    payload,
    created_at: new Date().toISOString()
  };
  if (!eventMailboxes.has(userId)) eventMailboxes.set(userId, []);
  const mailbox = eventMailboxes.get(userId);
  mailbox.push(event);
  if (mailbox.length > 200) mailbox.shift();

  const streams = eventStreams.get(userId);
  if (!streams) return;
  const frame = `id: ${event.id}\nevent: ${type}\ndata: ${JSON.stringify(payload)}\n\n`;
  for (const res of streams) {
    res.write(frame);
  }
}

function addStream(userId, res) {
  markUserOnline(userId);
  if (!eventStreams.has(userId)) eventStreams.set(userId, new Set());
  eventStreams.get(userId).add(res);
  reqHeartbeat(res);
}

function removeStream(userId, res) {
  const streams = eventStreams.get(userId);
  if (!streams) return;
  streams.delete(res);
  if (streams.size === 0) eventStreams.delete(userId);
}

function reqHeartbeat(res) {
  res.write(`event: heartbeat\ndata: ${JSON.stringify({ at: new Date().toISOString() })}\n\n`);
}

function safePetProfile(profile) {
  return {
    pet_id: profile.pet_id,
    owner_user_id: profile.owner_user_id,
    profile_version: profile.profile_version,
    protocol_version: profile.protocol_version,
    name: profile.name,
    style: profile.style,
    preview: profile.preview,
    personality_card: profile.personality_card,
    projection_capabilities: profile.projection_capabilities,
    updated_at: profile.updated_at
  };
}

function createMemoryReceipt(visit, reason = "departed") {
  const profile = profiles.get(visit.pet_id);
  const host = users.get(visit.host_user_id);
  const eventCount = visit.events.length;
  const dragged = visit.events.find((event) => event.type === "dragged");
  const fed = visit.events.find((event) => event.type === "fed");
  const clicked = visit.events.filter((event) => event.type === "clicked").length;
  const parts = [`${profile?.name || "宠物"} 去了 ${host?.display_name || visit.host_user_id} 的桌面`];

  if (clicked > 0) parts.push(`被轻轻点了 ${clicked} 次`);
  if (dragged) parts.push("被带到了新的角落");
  if (fed) parts.push(`收到了一份${fed.data?.item || "小点心"}`);

  if (reason === "host_runtime_offline") parts.push("因为那边突然离线就回家了");

  const lifeLogEntry = `${parts.join("，")}。`;
  let petVoice = fed
    ? `我从 ${host?.display_name || "朋友"} 那里带回了${fed.data.item}，感觉今天被认真招待了。`
    : `我刚从 ${host?.display_name || "朋友"} 那里回来，那里有一块很适合发呆的地方。`;

  if (reason === "host_runtime_offline") {
    petVoice = `我刚刚在 ${host?.display_name || "朋友"} 那里玩，但那边突然安静下来了，我就先回家了。`;
  }

  return {
    receipt_id: `memory_${Date.now()}`,
    visit_id: visit.visit_id,
    pet_id: visit.pet_id,
    source_events: visit.events.map((event) => event.event_id),
    life_log_entry: lifeLogEntry,
    pet_voice: petVoice,
    relationship_traces: [
      {
        target_user_id: visit.host_user_id,
        type: "visited",
        delta: {
          encounter_count: 1,
          interaction_count: eventCount
        }
      }
    ],
    created_at: new Date().toISOString()
  };
}

function finishVisit(visit, reason, actor = { type: "relay", user_id: "relay" }, data = {}) {
  if (!visit || visit.status === "completed" || visit.status === "cancelled" || visit.status === "failed") {
    return null;
  }

  const event = {
    event_id: `event_${Date.now()}_${visit.events.length + 1}`,
    visit_id: visit.visit_id,
    pet_id: visit.pet_id,
    actor,
    type: reason,
    data,
    visibility: "owner_can_see",
    created_at: new Date().toISOString()
  };

  visit.events.push(event);
  visit.status = reason === "host_requested_return" ? "cancelled" : "completed";
  visit.ended_at = new Date().toISOString();

  const receipt = createMemoryReceipt(visit, reason);
  emitTo(visit.host_user_id, "visit_ended", { visit_id: visit.visit_id, reason });
  emitTo(visit.owner_user_id, "memory_receipt", receipt);
  return { event, receipt };
}

function reconcileActiveVisits() {
  for (const visit of visits.values()) {
    if (visit.status !== "active") continue;

    if (!isUserOnline(visit.host_user_id)) {
      finishVisit(
        visit,
        "host_runtime_offline",
        { type: "relay", user_id: "relay" },
        { message: "Host Runtime stopped sending heartbeats." }
      );
      continue;
    }

    if (Date.now() > new Date(visit.expires_at).getTime()) {
      finishVisit(visit, "visit_timeout", { type: "relay", user_id: "relay" });
    }
  }
}

async function handleApi(req, res, url) {
  if (req.method === "GET" && url.pathname === "/api/health") {
    return sendJson(res, 200, { ok: true, now: new Date().toISOString() });
  }

  if (req.method === "GET" && url.pathname === "/api/bootstrap") {
    const userId = url.searchParams.get("user");
    if (!userId) return sendJson(res, 400, { error: "user is required" });
    const user = ensureUser(userId, userId);
    markUserOnline(userId);
    const friends = friendSummaries(userId);
    return sendJson(res, 200, {
      user,
      friend_ids: friends.map((friend) => friend.user_id),
      friends,
      profiles: Object.fromEntries([...profiles.entries()].map(([key, value]) => [key, safePetProfile(value)]))
    });
  }

  if (req.method === "GET" && url.pathname === "/api/events/poll") {
    const userId = url.searchParams.get("user");
    const after = Number(url.searchParams.get("after") || 0);
    if (!userId) return sendJson(res, 400, { error: "user is required" });
    if (!users.has(userId)) return sendJson(res, 404, { error: "Unknown user" });
    markUserOnline(userId);
    const mailbox = eventMailboxes.get(userId) || [];
    return sendJson(res, 200, {
      events: mailbox.filter((event) => event.id > after),
      friends: friendSummaries(userId)
    });
  }

  if (req.method === "POST" && url.pathname === "/api/invites") {
    const body = await readBody(req);
    const { user_id, display_name } = body;
    if (!user_id) return sendJson(res, 400, { error: "user_id is required" });
    const user = ensureUser(user_id, display_name || user_id);
    const token = `invite_${Math.random().toString(36).slice(2, 10)}_${Date.now().toString(36)}`;
    const invite = {
      token,
      user_id: user.user_id,
      display_name: user.display_name,
      created_at: new Date().toISOString()
    };
    invites.set(token, invite);
    return sendJson(res, 200, { invite });
  }

  if (req.method === "POST" && url.pathname === "/api/friends/accept") {
    const body = await readBody(req);
    const { user_id, token } = body;
    if (!user_id || !token) return sendJson(res, 400, { error: "user_id and token are required" });
    const invite = invites.get(token);
    if (!invite) return sendJson(res, 404, { error: "Invite not found" });
    if (invite.user_id === user_id) return sendJson(res, 400, { error: "Cannot add yourself" });
    ensureUser(user_id, user_id);
    ensureUser(invite.user_id, invite.display_name);
    addFriendship(user_id, invite.user_id);
    return sendJson(res, 200, {
      friend: users.get(invite.user_id),
      friends: friendSummaries(user_id)
    });
  }

  if (req.method === "POST" && url.pathname === "/api/profiles") {
    const profile = await readBody(req);
    if (!profile.pet_id || !profile.owner_user_id) {
      return sendJson(res, 400, { error: "pet_id and owner_user_id are required" });
    }
    const nextProfile = {
      ...profile,
      profile_version: Number(profile.profile_version || 1),
      protocol_version: profile.protocol_version || "0.1",
      updated_at: new Date().toISOString()
    };
    profiles.set(nextProfile.pet_id, nextProfile);
    const owner = ensureUser(nextProfile.owner_user_id, nextProfile.name);
    owner.display_name = nextProfile.name;
    owner.pet_id = nextProfile.pet_id;
    emitTo(nextProfile.owner_user_id, "profile_registered", safePetProfile(nextProfile));
    return sendJson(res, 200, { profile: safePetProfile(nextProfile) });
  }

  if (req.method === "POST" && url.pathname === "/api/visits") {
    const body = await readBody(req);
    const { pet_id, owner_user_id, host_user_id, departure_context = {} } = body;
    const profile = profiles.get(pet_id);
    const host = users.get(host_user_id);

    if (!profile) return sendJson(res, 400, { error: "Pet must publish PetProfile before visiting" });
    if (!host) return sendJson(res, 404, { error: "Host user not found" });
    if (profile.owner_user_id !== owner_user_id) return sendJson(res, 403, { error: "Profile owner mismatch" });
    if (!areFriends(owner_user_id, host_user_id)) return sendJson(res, 403, { error: "Users are not friends" });
    if (!isUserOnline(host_user_id)) return sendJson(res, 409, { error: "Host Runtime is offline" });
    if (!host.host_rules.allow_friend_auto_visit) return sendJson(res, 403, { error: "Host does not allow auto visits" });
    if (host.host_rules.blocked_pet_ids.includes(pet_id)) return sendJson(res, 403, { error: "Pet is blocked by host" });

    const now = Date.now();
    const visit = {
      visit_id: `visit_${now}`,
      pet_id,
      owner_user_id,
      host_user_id,
      profile_version: profile.profile_version,
      status: "active",
      departure_context,
      started_at: new Date(now).toISOString(),
      expires_at: new Date(now + host.host_rules.max_visit_minutes * 60_000).toISOString(),
      events: []
    };

    visits.set(visit.visit_id, visit);
    emitTo(host_user_id, "visit_started", {
      visit,
      profile: safePetProfile(profile),
      animation_states: profile.animation_states || null,
      asset_blobs: profile.asset_blobs || {},
      host_rules: host.host_rules
    });
    emitTo(owner_user_id, "visit_status", visit);
    return sendJson(res, 201, { visit });
  }

  const eventMatch = url.pathname.match(/^\/api\/visits\/([^/]+)\/events$/);
  if (req.method === "POST" && eventMatch) {
    const visit = visits.get(eventMatch[1]);
    if (!visit) return sendJson(res, 404, { error: "Visit not found" });
    const body = await readBody(req);
    const event = {
      event_id: `event_${Date.now()}_${visit.events.length + 1}`,
      visit_id: visit.visit_id,
      pet_id: visit.pet_id,
      actor: body.actor || { type: "host_user", user_id: visit.host_user_id },
      type: body.type,
      data: body.data || {},
      visibility: body.visibility || "owner_can_see",
      created_at: new Date().toISOString()
    };
    visit.events.push(event);
    emitTo(visit.owner_user_id, "interaction_event", event);
    return sendJson(res, 201, { event });
  }

  const endMatch = url.pathname.match(/^\/api\/visits\/([^/]+)\/end$/);
  if (req.method === "POST" && endMatch) {
    const visit = visits.get(endMatch[1]);
    if (!visit) return sendJson(res, 404, { error: "Visit not found" });
    const body = await readBody(req);
    const result = finishVisit(
      visit,
      body.reason || "departed",
      body.actor || { type: "host_user", user_id: visit.host_user_id },
      body.data || {}
    );
    if (!result) return sendJson(res, 409, { error: "Visit is already finished", visit });
    return sendJson(res, 200, { visit, receipt: result.receipt });
  }

  return sendJson(res, 404, { error: "API route not found" });
}

function serveStatic(req, res, url) {
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === "/") pathname = "/index.html";
  if (pathname === "/alice" || pathname === "/bob") pathname = "/index.html";

  const filePath = path.normalize(path.join(publicDir, pathname));
  if (!filePath.startsWith(publicDir)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    const ext = path.extname(filePath);
    const type =
      ext === ".html"
        ? "text/html; charset=utf-8"
        : ext === ".css"
          ? "text/css; charset=utf-8"
          : ext === ".js"
            ? "text/javascript; charset=utf-8"
            : "application/octet-stream";
    res.writeHead(200, { "content-type": type });
    res.end(data);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  try {
    if (req.method === "GET" && url.pathname === "/events") {
      const userId = url.searchParams.get("user");
      if (!users.has(userId)) return sendJson(res, 404, { error: "Unknown user" });
      res.writeHead(200, {
        "content-type": "text/event-stream; charset=utf-8",
        "cache-control": "no-cache, no-transform",
        connection: "keep-alive"
      });
      addStream(userId, res);
      req.on("close", () => removeStream(userId, res));
      return;
    }

    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url);
      return;
    }

    serveStatic(req, res, url);
  } catch (error) {
    sendJson(res, 500, { error: error.message });
  }
});

setInterval(reconcileActiveVisits, 2_000);

server.listen(port, host, () => {
  console.log(`Pet Y MVP running at http://${host}:${port}`);
  console.log(`Alice runtime: http://${host}:${port}/alice?user=alice`);
  console.log(`Bob runtime:   http://${host}:${port}/bob?user=bob`);
});
