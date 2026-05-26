import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, "public");
const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || "127.0.0.1";
const relayOnly = process.env.PET_Y_RELAY_ONLY === "1";
const analyticsPath = process.env.PET_Y_ANALYTICS_PATH || path.join(__dirname, "data", "analytics.jsonl");
const relayStatePath = process.env.PET_Y_STATE_PATH || path.join(__dirname, "data", "relay-state.json");
const analyticsSalt = process.env.PET_Y_ANALYTICS_SALT || "pet-y-mvp";
const adminToken = process.env.PET_Y_ADMIN_TOKEN || "";

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
const visitInvitations = new Map();
const eventStreams = new Map();
const eventMailboxes = new Map();
const runtimePresence = new Map();
let eventSequence = 0;
const onlineTimeoutMs = 60_000;
const visitRequestTimeoutMs = 60_000;
const counters = new Map();
const seenUsers = new Set();
const seenPets = new Set();

function loadRelayState() {
  if (!fs.existsSync(relayStatePath)) return;
  try {
    const state = JSON.parse(fs.readFileSync(relayStatePath, "utf8"));
    for (const user of state.users || []) {
      if (!user?.user_id) continue;
      users.set(user.user_id, {
        ...user,
        host_rules: { ...defaultHostRules(), ...(user.host_rules || {}) }
      });
    }
    for (const friendship of state.friendships || []) {
      if (typeof friendship === "string") friendships.add(friendship);
    }
    for (const invite of state.invites || []) {
      if (invite?.token && invite?.user_id) invites.set(invite.token, invite);
    }
    for (const profile of state.profiles || []) {
      if (profile?.pet_id && profile?.owner_user_id) profiles.set(profile.pet_id, profile);
    }
  } catch (error) {
    console.error(`Failed to load Relay state: ${error.message}`);
  }
}

function saveRelayState() {
  const state = {
    saved_at: new Date().toISOString(),
    users: [...users.values()],
    friendships: [...friendships.values()],
    invites: [...invites.values()],
    profiles: [...profiles.values()]
  };
  fs.mkdir(path.dirname(relayStatePath), { recursive: true }, (mkdirError) => {
    if (mkdirError) return;
    fs.writeFile(relayStatePath, JSON.stringify(state, null, 2), () => {});
  });
}

function countMetric(name, amount = 1) {
  counters.set(name, (counters.get(name) || 0) + amount);
}

function anonymize(value) {
  if (!value) return null;
  return crypto.createHash("sha256").update(`${analyticsSalt}:${value}`).digest("hex").slice(0, 16);
}

function recordAnalytics(name, fields = {}) {
  countMetric(name);
  const userIds = [fields.user_id, fields.owner_user_id, fields.host_user_id, fields.actor_user_id].filter(Boolean);
  for (const userId of userIds) seenUsers.add(userId);
  if (fields.pet_id) seenPets.add(fields.pet_id);

  const entry = {
    at: new Date().toISOString(),
    name,
    user_hash: anonymize(fields.user_id),
    owner_hash: anonymize(fields.owner_user_id),
    host_hash: anonymize(fields.host_user_id),
    actor_hash: anonymize(fields.actor_user_id),
    pet_hash: anonymize(fields.pet_id),
    event_type: fields.event_type || null,
    reason: fields.reason || null
  };

  fs.mkdir(path.dirname(analyticsPath), { recursive: true }, (error) => {
    if (error) return;
    fs.appendFile(analyticsPath, `${JSON.stringify(entry)}\n`, () => {});
  });
}

function analyticsSummaryFromFile() {
  const summary = {
    events_total: 0,
    counters: {},
    unique_users: 0,
    unique_pets: 0,
    event_types: {},
    last_event_at: null
  };
  if (!fs.existsSync(analyticsPath)) return summary;

  const userHashes = new Set();
  const petHashes = new Set();
  const lines = fs.readFileSync(analyticsPath, "utf8").split("\n");
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const entry = JSON.parse(line);
      summary.events_total += 1;
      summary.last_event_at = entry.at || summary.last_event_at;
      summary.counters[entry.name] = (summary.counters[entry.name] || 0) + 1;
      for (const key of ["user_hash", "owner_hash", "host_hash", "actor_hash"]) {
        if (entry[key]) userHashes.add(entry[key]);
      }
      if (entry.pet_hash) petHashes.add(entry.pet_hash);
      if (entry.event_type) {
        summary.event_types[entry.event_type] = (summary.event_types[entry.event_type] || 0) + 1;
      }
    } catch {
      // Ignore malformed analytics lines.
    }
  }
  summary.unique_users = userHashes.size;
  summary.unique_pets = petHashes.size;
  return summary;
}

function isLocalRequest(req) {
  const address = req.socket.remoteAddress || "";
  return address === "127.0.0.1" || address === "::1" || address === "::ffff:127.0.0.1";
}

function canReadAdminStats(req, url) {
  if (adminToken && url.searchParams.get("token") === adminToken) return true;
  return isLocalRequest(req);
}

function currentStats() {
  return {
    now: new Date().toISOString(),
    runtime: {
      users_total: users.size,
      profiles_total: profiles.size,
      friendships_total: friendships.size / 2,
      invites_total: invites.size,
      visits_total: visits.size,
      active_visits: [...visits.values()].filter((visit) => visit.status === "active").length,
      online_users: [...users.keys()].filter(isUserOnline).length
    },
    counters: Object.fromEntries(counters.entries()),
    seen_since_start: {
      users: seenUsers.size,
      pets: seenPets.size
    },
    persisted: analyticsSummaryFromFile()
  };
}

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
  seenUsers.add(userId);
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
    do_not_disturb_until: null,
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

loadRelayState();

function addFriendship(a, b) {
  friendships.add(friendshipKey(a, b));
  friendships.add(friendshipKey(b, a));
}

function friendSummaryFor(userId, friendId) {
  return friendSummaries(userId).find((friend) => friend.user_id === friendId) || null;
}

function isExpiredAt(value) {
  return Boolean(value && Date.now() > new Date(value).getTime());
}

function isDeliverableMailboxEvent(event) {
  if (event.type === "visit_requested") {
    const visitId = event.payload?.visit?.visit_id;
    const visit = visitId ? visits.get(visitId) : null;
    if (!visit || visit.status !== "pending") return false;

    if (isExpiredAt(visit.request_expires_at)) {
      visit.status = "cancelled";
      visit.ended_at = new Date().toISOString();
      emitTo(visit.owner_user_id, "visit_status", visit);
      emitTo(visit.host_user_id, "visit_status", visit);
      return false;
    }

    return true;
  }

  if (event.type !== "visit_invitation_requested") return true;

  const requestId = event.payload?.invitation?.request_id;
  const invitation = requestId ? visitInvitations.get(requestId) : null;
  if (!invitation || invitation.status !== "pending") return false;

  if (isExpiredAt(invitation.expires_at)) {
    invitation.status = "expired";
    invitation.ended_at = new Date().toISOString();
    return false;
  }

  return true;
}

function emitTo(userId, type, payload) {
  const snapshot = JSON.parse(JSON.stringify(payload));
  const event = {
    id: ++eventSequence,
    type,
    payload: snapshot,
    created_at: new Date().toISOString()
  };
  if (!eventMailboxes.has(userId)) eventMailboxes.set(userId, []);
  const mailbox = eventMailboxes.get(userId);
  mailbox.push(event);
  if (mailbox.length > 200) mailbox.shift();

  const streams = eventStreams.get(userId);
  if (!streams) return;
  const frame = `id: ${event.id}\nevent: ${type}\ndata: ${JSON.stringify(snapshot)}\n\n`;
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
    interaction_capabilities: profile.interaction_capabilities || null,
    updated_at: profile.updated_at
  };
}

function cleanMessageText(text) {
  return String(text || "").trim().slice(0, 500);
}

function isDoNotDisturb(user) {
  const until = user?.host_rules?.do_not_disturb_until;
  return Boolean(until && Date.now() < new Date(until).getTime());
}

function doNotDisturbMessage(user) {
  return `${user?.display_name || "这个宠物"}正在睡觉呢。`;
}

function activeVisitFor(petId, ownerUserId, hostUserId) {
  return [...visits.values()].find((visit) =>
    visit.pet_id === petId &&
    visit.owner_user_id === ownerUserId &&
    visit.host_user_id === hostUserId &&
    ["pending", "active"].includes(visit.status)
  );
}

function ownerProfileFor(userId) {
  return [...profiles.values()].find((profile) => profile.owner_user_id === userId) || null;
}

function createVisit({ pet_id, owner_user_id, host_user_id, departure_context = {}, status = "pending" }) {
  const profile = profiles.get(pet_id);
  const host = users.get(host_user_id);
  const now = Date.now();
  const visit = {
    visit_id: `visit_${now}`,
    pet_id,
    owner_user_id,
    host_user_id,
    profile_version: profile.profile_version,
    status,
    departure_context,
    requested_at: new Date(now).toISOString(),
    request_expires_at: new Date(now + visitRequestTimeoutMs).toISOString(),
    started_at: status === "active" ? new Date(now).toISOString() : null,
    expires_at: new Date(now + host.host_rules.max_visit_minutes * 60_000).toISOString(),
    events: []
  };
  visits.set(visit.visit_id, visit);
  return visit;
}

function emitVisitStarted(visit, profile) {
  const safeProfile = safePetProfile(profile);
  const payload = {
    visit,
    profile: safeProfile,
    animation_states: profile.animation_states || null,
    asset_blobs: profile.asset_blobs || {},
    host_rules: users.get(visit.host_user_id)?.host_rules || defaultHostRules()
  };
  emitTo(visit.host_user_id, "visit_started", payload);
  emitTo(visit.owner_user_id, "visit_status", visit);
}

function createMemoryReceipt(visit, reason = "departed") {
  const profile = profiles.get(visit.pet_id);
  const host = users.get(visit.host_user_id);
  const eventCount = visit.events.length;
  const dragged = visit.events.find((event) => event.type === "dragged");
  const fed = visit.events.find((event) => event.type === "fed");
  const messages = visit.events.filter((event) => event.type === "message" && event.data?.text);
  const messageSummaries = messages.map((event) => ({
    event_id: event.event_id,
    text: cleanMessageText(event.data?.text),
    author_user_id: event.actor?.user_id || visit.host_user_id,
    author_name: users.get(event.actor?.user_id)?.display_name || host?.display_name || "朋友",
    created_at: event.created_at
  }));
  const greeted = visit.events.find((event) => event.type === "pet_to_pet.greeting");
  const satTogether = visit.events.find((event) => event.type === "pet_to_pet.sit_together");
  const playedTogether = visit.events.find((event) => event.type === "pet_to_pet.walk_together");
  const autonomousRoam = visit.events.find((event) => event.type === "visitor_autonomous_roam");
  const clicked = visit.events.filter((event) => event.type === "clicked").length;
  const parts = [`${profile?.name || "宠物"} 去了 ${host?.display_name || visit.host_user_id} 的桌面`];

  if (clicked > 0) parts.push(`被轻轻点了 ${clicked} 次`);
  if (dragged) parts.push("被带到了新的角落");
  if (fed) parts.push(`收到了一份${fed.data?.item || "小点心"}`);
  if (messages.length > 0) parts.push(`收到了 ${messages.length} 条留言`);
  if (greeted) parts.push("和那边的宠物打了招呼");
  if (satTogether) parts.push("和那边的宠物靠在一起坐了一会儿");
  if (playedTogether) {
    const peerName = playedTogether.data?.peer_pet_name;
    parts.push(peerName ? `和 ${peerName} 一起跑去玩了一会儿` : "和那边的宠物一起跑去玩了一会儿");
  }
  if (autonomousRoam) parts.push("自己在那边桌面上逛了逛");

  if (reason === "host_runtime_offline") parts.push("因为那边突然离线就回家了");

  const lifeLogEntry = `${parts.join("，")}。`;
  let petVoice = fed
    ? `我从 ${host?.display_name || "朋友"} 那里带回了${fed.data.item}，感觉今天被认真招待了。`
    : `我刚从 ${host?.display_name || "朋友"} 那里回来，那里有一块很适合发呆的地方。`;
  if (!fed && messages.length > 0) {
    petVoice = `我从 ${host?.display_name || "朋友"} 那里带回了留言。`;
  }
  if (!fed && messages.length === 0 && playedTogether) {
    petVoice = `我刚刚和 ${host?.display_name || "朋友"} 那边的宠物一起跑去玩了一会儿。`;
  }
  if (!fed && messages.length === 0 && !playedTogether && satTogether) {
    petVoice = `我刚刚和 ${host?.display_name || "朋友"} 那边的宠物安静坐了一会儿。`;
  }
  if (!fed && messages.length === 0 && !playedTogether && !satTogether && greeted) {
    petVoice = `我刚刚和 ${host?.display_name || "朋友"} 那边的宠物打了个招呼。`;
  }
  if (!fed && messages.length === 0 && !playedTogether && !satTogether && !greeted && autonomousRoam) {
    petVoice = `我在 ${host?.display_name || "朋友"} 那边自己逛了逛，找到了一个新角落。`;
  }

  if (reason === "host_runtime_offline") {
    petVoice = `我刚刚在 ${host?.display_name || "朋友"} 那里玩，但那边突然安静下来了，我就先回家了。`;
  }
  if (reason === "owner_requested_return") {
    petVoice = `我听见你喊我，就从 ${host?.display_name || "朋友"} 那里跑回来了。`;
  }

  return {
    receipt_id: `memory_${Date.now()}`,
    visit_id: visit.visit_id,
    pet_id: visit.pet_id,
    source_events: visit.events.map((event) => event.event_id),
    life_log_entry: lifeLogEntry,
    pet_voice: petVoice,
    messages: messageSummaries,
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
  if (!visit || visit.status === "completed" || visit.status === "cancelled" || visit.status === "declined" || visit.status === "failed") {
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
  recordAnalytics("visit_finished", {
    owner_user_id: visit.owner_user_id,
    host_user_id: visit.host_user_id,
    pet_id: visit.pet_id,
    event_type: reason,
    reason
  });

  const receipt = createMemoryReceipt(visit, reason);
  emitTo(visit.host_user_id, "visit_ended", { visit_id: visit.visit_id, reason });
  emitTo(visit.owner_user_id, "memory_receipt", receipt);
  return { event, receipt };
}

function reconcileActiveVisits() {
  for (const visit of visits.values()) {
    if (visit.status === "pending") {
      if (!isUserOnline(visit.host_user_id)) {
        visit.status = "failed";
        visit.ended_at = new Date().toISOString();
        emitTo(visit.owner_user_id, "visit_status", visit);
        emitTo(visit.host_user_id, "visit_status", visit);
        continue;
      }
      if (Date.now() > new Date(visit.request_expires_at).getTime()) {
        visit.status = "cancelled";
        visit.ended_at = new Date().toISOString();
        emitTo(visit.owner_user_id, "visit_status", visit);
        emitTo(visit.host_user_id, "visit_status", visit);
      }
      continue;
    }

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

  if (req.method === "GET" && url.pathname === "/api/admin/stats") {
    if (!canReadAdminStats(req, url)) return sendJson(res, 403, { error: "Admin stats require local access or token" });
    return sendJson(res, 200, currentStats());
  }

  if (req.method === "GET" && url.pathname === "/api/bootstrap") {
    const userId = url.searchParams.get("user");
    if (!userId) return sendJson(res, 400, { error: "user is required" });
    const user = ensureUser(userId, userId);
    markUserOnline(userId);
    recordAnalytics("bootstrap", { user_id: userId, pet_id: user.pet_id });
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
    countMetric("events_poll");
    const mailbox = eventMailboxes.get(userId) || [];
    return sendJson(res, 200, {
      events: mailbox.filter((event) => event.id > after && isDeliverableMailboxEvent(event)),
      friends: friendSummaries(userId)
    });
  }

  if (req.method === "POST" && url.pathname === "/api/invites") {
    const body = await readBody(req);
    const { user_id, display_name } = body;
    if (!user_id) return sendJson(res, 400, { error: "user_id is required" });
    const user = ensureUser(user_id, display_name || user_id);
    recordAnalytics("invite_created", { user_id });
    const token = `invite_${Math.random().toString(36).slice(2, 10)}_${Date.now().toString(36)}`;
    const invite = {
      token,
      user_id: user.user_id,
      display_name: user.display_name,
      created_at: new Date().toISOString()
    };
    invites.set(token, invite);
    saveRelayState();
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
    saveRelayState();
    recordAnalytics("friend_added", { user_id, host_user_id: invite.user_id });
    emitTo(invite.user_id, "friend_added", {
      friend: friendSummaryFor(invite.user_id, user_id)
    });
    return sendJson(res, 200, {
      friend: users.get(invite.user_id),
      friends: friendSummaries(user_id)
    });
  }

  const dndMatch = url.pathname.match(/^\/api\/users\/([^/]+)\/do-not-disturb$/);
  if (req.method === "POST" && dndMatch) {
    const user = users.get(dndMatch[1]);
    if (!user) return sendJson(res, 404, { error: "Unknown user" });
    const body = await readBody(req);
    if (body.user_id !== user.user_id) return sendJson(res, 403, { error: "Only the user can update do-not-disturb" });
    user.host_rules.do_not_disturb_until = body.until || null;
    saveRelayState();
    recordAnalytics("do_not_disturb_updated", {
      user_id: user.user_id,
      reason: user.host_rules.do_not_disturb_until ? "enabled" : "disabled"
    });
    return sendJson(res, 200, {
      user_id: user.user_id,
      do_not_disturb_until: user.host_rules.do_not_disturb_until
    });
  }

  if (req.method === "POST" && url.pathname === "/api/visit-invitations") {
    const body = await readBody(req);
    const { requester_user_id, owner_user_id } = body;
    const requester = users.get(requester_user_id);
    const owner = users.get(owner_user_id);
    const profile = ownerProfileFor(owner_user_id);
    if (!requester_user_id || !owner_user_id) return sendJson(res, 400, { error: "requester_user_id and owner_user_id are required" });
    if (!requester || !owner) return sendJson(res, 404, { error: "User not found" });
    if (!areFriends(requester_user_id, owner_user_id)) return sendJson(res, 403, { error: "Users are not friends" });
    if (!profile) return sendJson(res, 400, { error: "Friend pet must publish PetProfile before visiting" });
    if (!isUserOnline(owner_user_id)) return sendJson(res, 409, { error: "Friend Runtime is offline" });
    if (isDoNotDisturb(owner)) return sendJson(res, 409, { error: doNotDisturbMessage(owner) });

    const existing = activeVisitFor(profile.pet_id, owner_user_id, requester_user_id);
    if (existing) return sendJson(res, 200, { invitation: null, visit: existing });

    const requestId = `invite_visit_${Date.now()}`;
    const invitation = {
      request_id: requestId,
      requester_user_id,
      owner_user_id,
      pet_id: profile.pet_id,
      status: "pending",
      created_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + visitRequestTimeoutMs).toISOString()
    };
    visitInvitations.set(requestId, invitation);
    recordAnalytics("visit_invitation_requested", { user_id: requester_user_id, owner_user_id, pet_id: profile.pet_id });
    emitTo(owner_user_id, "visit_invitation_requested", {
      invitation,
      requester: friendSummaryFor(owner_user_id, requester_user_id) || requester,
      profile: safePetProfile(profile)
    });
    return sendJson(res, 201, { invitation });
  }

  const invitationDecisionMatch = url.pathname.match(/^\/api\/visit-invitations\/([^/]+)\/decision$/);
  if (req.method === "POST" && invitationDecisionMatch) {
    const invitation = visitInvitations.get(invitationDecisionMatch[1]);
    if (!invitation) return sendJson(res, 404, { error: "Visit invitation not found" });
    const body = await readBody(req);
    if (body.user_id !== invitation.owner_user_id) return sendJson(res, 403, { error: "Only the pet owner can answer the invitation" });
    if (invitation.status !== "pending") return sendJson(res, 409, { error: "Visit invitation is no longer pending", invitation });
    if (isExpiredAt(invitation.expires_at)) {
      invitation.status = "expired";
      invitation.ended_at = new Date().toISOString();
      return sendJson(res, 409, { error: "Visit invitation expired", invitation });
    }
    const owner = users.get(invitation.owner_user_id);
    const requester = users.get(invitation.requester_user_id);
    const profile = profiles.get(invitation.pet_id);
    if (!owner || !requester || !profile) return sendJson(res, 409, { error: "Visit invitation cannot start now" });

    if (body.action === "decline") {
      invitation.status = "declined";
      invitation.ended_at = new Date().toISOString();
      emitTo(invitation.requester_user_id, "visit_invitation_status", invitation);
      return sendJson(res, 200, { invitation, visit: null });
    }
    if (body.action !== "accept") return sendJson(res, 400, { error: "action must be accept or decline" });
    if (!isUserOnline(invitation.requester_user_id)) return sendJson(res, 409, { error: "Requester Runtime is offline" });
    if (isDoNotDisturb(requester)) return sendJson(res, 409, { error: doNotDisturbMessage(requester) });

    const existing = activeVisitFor(invitation.pet_id, invitation.owner_user_id, invitation.requester_user_id);
    const visit = existing || createVisit({
      pet_id: invitation.pet_id,
      owner_user_id: invitation.owner_user_id,
      host_user_id: invitation.requester_user_id,
      departure_context: { mood: "invited", intent: "play" },
      status: "active"
    });
    invitation.status = "accepted";
    invitation.visit_id = visit.visit_id;
    invitation.ended_at = new Date().toISOString();
    if (!existing) {
      recordAnalytics("visit_started", {
        owner_user_id: visit.owner_user_id,
        host_user_id: visit.host_user_id,
        pet_id: visit.pet_id
      });
      emitVisitStarted(visit, profile);
    }
    emitTo(invitation.requester_user_id, "visit_invitation_status", invitation);
    return sendJson(res, 200, { invitation, visit });
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
    saveRelayState();
    recordAnalytics("profile_registered", {
      user_id: nextProfile.owner_user_id,
      pet_id: nextProfile.pet_id
    });
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
    if (isDoNotDisturb(host)) return sendJson(res, 409, { error: doNotDisturbMessage(host) });
    if (host.host_rules.blocked_pet_ids.includes(pet_id)) return sendJson(res, 403, { error: "Pet is blocked by host" });

    const existing = activeVisitFor(pet_id, owner_user_id, host_user_id);
    if (existing) return sendJson(res, 200, { visit: existing });

    const visit = createVisit({ pet_id, owner_user_id, host_user_id, departure_context });
    recordAnalytics("visit_requested", { owner_user_id, host_user_id, pet_id });
    emitTo(host_user_id, "visit_requested", {
      visit,
      profile: safePetProfile(profile),
      animation_states: profile.animation_states || null,
      asset_blobs: profile.asset_blobs || {},
      host_rules: host.host_rules
    });
    emitTo(owner_user_id, "visit_status", visit);
    return sendJson(res, 201, { visit });
  }

  const decisionMatch = url.pathname.match(/^\/api\/visits\/([^/]+)\/decision$/);
  if (req.method === "POST" && decisionMatch) {
    const visit = visits.get(decisionMatch[1]);
    if (!visit) return sendJson(res, 404, { error: "Visit not found" });
    const body = await readBody(req);
    if (body.user_id !== visit.host_user_id) return sendJson(res, 403, { error: "Only the host can answer the door" });
    if (visit.status !== "pending") return sendJson(res, 409, { error: "Visit request is no longer pending", visit });
    if (isExpiredAt(visit.request_expires_at)) {
      visit.status = "cancelled";
      visit.ended_at = new Date().toISOString();
      emitTo(visit.owner_user_id, "visit_status", visit);
      emitTo(visit.host_user_id, "visit_status", visit);
      return sendJson(res, 409, { error: "Visit request expired", visit });
    }

    if (body.action === "decline") {
      visit.status = "declined";
      visit.ended_at = new Date().toISOString();
      recordAnalytics("visit_declined", {
        owner_user_id: visit.owner_user_id,
        host_user_id: visit.host_user_id,
        pet_id: visit.pet_id
      });
      emitTo(visit.owner_user_id, "visit_status", visit);
      return sendJson(res, 200, { visit });
    }

    if (body.action !== "accept") return sendJson(res, 400, { error: "action must be accept or decline" });

    const profile = profiles.get(visit.pet_id);
    const host = users.get(visit.host_user_id);
    if (!profile || !host) return sendJson(res, 409, { error: "Visit cannot start now" });
    if (!isUserOnline(visit.host_user_id)) return sendJson(res, 409, { error: "Host Runtime is offline" });
    if (isDoNotDisturb(host)) return sendJson(res, 409, { error: doNotDisturbMessage(host) });

    const now = Date.now();
    visit.status = "active";
    visit.started_at = new Date(now).toISOString();
    visit.expires_at = new Date(now + host.host_rules.max_visit_minutes * 60_000).toISOString();
    recordAnalytics("visit_started", {
      owner_user_id: visit.owner_user_id,
      host_user_id: visit.host_user_id,
      pet_id: visit.pet_id
    });
    emitVisitStarted(visit, profile);
    return sendJson(res, 200, { visit });
  }

  const eventMatch = url.pathname.match(/^\/api\/visits\/([^/]+)\/events$/);
  if (req.method === "POST" && eventMatch) {
    const visit = visits.get(eventMatch[1]);
    if (!visit) return sendJson(res, 404, { error: "Visit not found" });
    if (visit.status !== "active") return sendJson(res, 409, { error: "Visit is not active" });
    const body = await readBody(req);
    if (body.type === "message" && !cleanMessageText(body.data?.text)) {
      return sendJson(res, 400, { error: "message text is required" });
    }
    const event = {
      event_id: `event_${Date.now()}_${visit.events.length + 1}`,
      visit_id: visit.visit_id,
      pet_id: visit.pet_id,
      actor: body.actor || { type: "host_user", user_id: visit.host_user_id },
      type: body.type,
      data: body.type === "message" ? { ...body.data, text: cleanMessageText(body.data?.text) } : body.data || {},
      visibility: body.visibility || "owner_can_see",
      created_at: new Date().toISOString()
    };
    visit.events.push(event);
    recordAnalytics("visit_event", {
      owner_user_id: visit.owner_user_id,
      host_user_id: visit.host_user_id,
      actor_user_id: event.actor?.user_id,
      pet_id: visit.pet_id,
      event_type: event.type
    });
    emitTo(visit.owner_user_id, "interaction_event", event);
    return sendJson(res, 201, { event });
  }

  const endMatch = url.pathname.match(/^\/api\/visits\/([^/]+)\/end$/);
  if (req.method === "POST" && endMatch) {
    const visit = visits.get(endMatch[1]);
    if (!visit) return sendJson(res, 404, { error: "Visit not found" });
    const body = await readBody(req);
    if (visit.status === "pending") {
      visit.status = "cancelled";
      visit.ended_at = new Date().toISOString();
      emitTo(visit.owner_user_id, "visit_status", visit);
      emitTo(visit.host_user_id, "visit_status", visit);
      return sendJson(res, 200, { visit, receipt: null });
    }
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
  if (relayOnly) {
    if (url.pathname === "/") {
      return sendJson(res, 200, {
        service: "Pet Y Relay",
        ok: true,
        website: "https://pet-y.vercel.app",
        health: "/api/health"
      });
    }
    return sendJson(res, 404, { error: "Relay-only mode does not serve public pages" });
  }

  let pathname = decodeURIComponent(url.pathname);
  if (pathname === "/") pathname = "/index.html";
  if (pathname === "/alice" || pathname === "/bob") pathname = "/runtime.html";

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
            : ext === ".png"
              ? "image/png"
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
