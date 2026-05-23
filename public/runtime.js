const params = new URLSearchParams(window.location.search);
const pathUser = window.location.pathname.includes("bob") ? "bob" : "alice";
const userId = params.get("user") || pathUser;

const defaultPets = {
  alice: {
    pet_id: "pet_momo",
    owner_user_id: "alice",
    profile_version: 1,
    protocol_version: "0.1",
    name: "Momo",
    style: "pixel",
    preview: "#6bc6a8",
    personality_card: "慢热但好奇，喜欢被轻轻拖到新的观察点。",
    projection_capabilities: ["idle", "walk", "sleep", "react_to_click", "react_to_drag", "receive_gift"]
  },
  bob: {
    pet_id: "pet_yuzu",
    owner_user_id: "bob",
    profile_version: 1,
    protocol_version: "0.1",
    name: "Yuzu",
    style: "sticker",
    preview: "#ee7b6c",
    personality_card: "外向、爱凑热闹，会把来访朋友带到屏幕边缘玩。",
    projection_capabilities: ["idle", "walk", "sleep", "react_to_click", "react_to_drag", "receive_gift"]
  }
};

const state = {
  user: null,
  friends: [],
  localPet: defaultPets[userId],
  activeVisitor: null,
  localVisit: null,
  logs: JSON.parse(localStorage.getItem(`pet-y:${userId}:logs`) || "[]"),
  protocolLogs: []
};

const $ = (selector) => document.querySelector(selector);
const desktop = $("#desktop");

function saveLogs() {
  localStorage.setItem(`pet-y:${userId}:logs`, JSON.stringify(state.logs.slice(0, 80)));
}

function addLifeLog(text) {
  state.logs.unshift({ text, at: new Date().toLocaleTimeString() });
  saveLogs();
  renderLogs();
}

function addProtocolLog(text) {
  state.protocolLogs.unshift({ text, at: new Date().toLocaleTimeString() });
  state.protocolLogs = state.protocolLogs.slice(0, 80);
  renderLogs();
}

function renderLogs() {
  $("#life-log").innerHTML =
    state.logs.map((entry) => `<li><strong>${entry.at}</strong><br>${entry.text}</li>`).join("") ||
    "<li>还没有生活日志。</li>";
  $("#protocol-log").innerHTML =
    state.protocolLogs.map((entry) => `<li><strong>${entry.at}</strong><br>${entry.text}</li>`).join("") ||
    "<li>等待协议事件。</li>";
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      "content-type": "application/json",
      ...(options.headers || {})
    }
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "Request failed");
  return data;
}

function createPetElement({ profile, visitor = false, visit = null, x = 120, y = 160 }) {
  const pet = document.createElement("button");
  pet.className = `pet ${visitor ? "visitor" : "local"}`;
  pet.type = "button";
  pet.style.setProperty("--x", `${x}px`);
  pet.style.setProperty("--y", `${y}px`);
  pet.style.setProperty("--pet-color", profile.preview || (visitor ? "#ee7b6c" : "#6bc6a8"));
  pet.dataset.x = x;
  pet.dataset.y = y;
  pet.innerHTML = `
    <div class="bubble" hidden>${visitor ? "我来串门啦。" : "我在这里。"}</div>
    <div class="pet-body">
      <span class="ear left"></span>
      <span class="ear right"></span>
      <span class="eye left"></span>
      <span class="eye right"></span>
      <span class="mouth"></span>
    </div>
    <div class="pet-label">${profile.name}${visitor ? " 来访中" : ""}</div>
  `;

  pet.addEventListener("click", async (event) => {
    if (pet.classList.contains("dragging")) return;
    showBubble(pet, visitor ? "谢谢你理我，我会记住的。" : "我在桌面上巡逻。");
    if (visitor && visit) {
      await recordVisitEvent(visit.visit_id, "clicked", { message: "host clicked visitor pet" });
    } else {
      addLifeLog(`${profile.name} 被你轻轻点了一下。`);
    }
    event.stopPropagation();
  });

  attachDrag(pet, async (from, to, durationMs) => {
    showBubble(pet, visitor ? "这个位置我还没来过。" : "这里视野不错。");
    if (visitor && visit) {
      await recordVisitEvent(visit.visit_id, "dragged", { from, to, duration_ms: durationMs });
    } else {
      addLifeLog(`${profile.name} 被拖到了新的位置。`);
    }
  });

  desktop.appendChild(pet);
  return pet;
}

function attachDrag(element, onEnd) {
  let start = null;
  let origin = null;
  let startAt = 0;

  element.addEventListener("pointerdown", (event) => {
    element.setPointerCapture(event.pointerId);
    element.classList.add("dragging");
    start = { x: event.clientX, y: event.clientY };
    origin = { x: Number(element.dataset.x), y: Number(element.dataset.y) };
    startAt = performance.now();
  });

  element.addEventListener("pointermove", (event) => {
    if (!start || !origin) return;
    const rect = desktop.getBoundingClientRect();
    const next = {
      x: Math.max(0, Math.min(rect.width - 92, origin.x + event.clientX - start.x)),
      y: Math.max(0, Math.min(rect.height - 110, origin.y + event.clientY - start.y))
    };
    element.dataset.x = next.x;
    element.dataset.y = next.y;
    element.style.setProperty("--x", `${next.x}px`);
    element.style.setProperty("--y", `${next.y}px`);
  });

  element.addEventListener("pointerup", async () => {
    if (!start || !origin) return;
    const to = { x: Number(element.dataset.x), y: Number(element.dataset.y) };
    const durationMs = Math.round(performance.now() - startAt);
    const moved = Math.abs(to.x - origin.x) + Math.abs(to.y - origin.y) > 8;
    start = null;
    origin = null;
    setTimeout(() => element.classList.remove("dragging"), 0);
    if (moved) await onEnd(origin, to, durationMs);
  });
}

function showBubble(pet, text) {
  const bubble = pet.querySelector(".bubble");
  bubble.textContent = text;
  bubble.hidden = false;
  clearTimeout(pet.bubbleTimer);
  pet.bubbleTimer = setTimeout(() => {
    bubble.hidden = true;
  }, 2600);
}

function clearVisitors() {
  for (const pet of desktop.querySelectorAll(".pet.visitor")) pet.remove();
  state.activeVisitor = null;
}

async function registerProfile() {
  const { profile } = await api("/api/profiles", {
    method: "POST",
    body: JSON.stringify(state.localPet)
  });
  addProtocolLog(`已注册宠物名片 ${profile.name} v${profile.profile_version}`);
  return profile;
}

async function sendVisit() {
  const friendId = $("#friend-select").value;
  if (!friendId) return;
  await registerProfile();
  const { visit } = await api("/api/visits", {
    method: "POST",
    body: JSON.stringify({
      pet_id: state.localPet.pet_id,
      owner_user_id: userId,
      host_user_id: friendId,
      departure_context: {
        mood: "curious",
        intent: "play",
        carried_items: [{ item_id: "strawberry", name: "草莓" }]
      }
    })
  });
  state.localVisit = visit;
  $("#visit-status").textContent = `${state.localPet.name} 已出发去 ${friendId} 的桌面。`;
  addLifeLog(`${state.localPet.name} 出门去 ${friendId} 的桌面串门。`);
  addProtocolLog(`创建 VisitSession：${visit.visit_id}`);
}

async function recordVisitEvent(visitId, type, data) {
  const { event } = await api(`/api/visits/${visitId}/events`, {
    method: "POST",
    body: JSON.stringify({
      type,
      data,
      actor: { type: "host_user", user_id: userId }
    })
  });
  addProtocolLog(`记录互动事件：${event.type}`);
}

async function feedVisitor() {
  if (!state.activeVisitor) {
    addProtocolLog("当前没有来访宠物可以投喂。");
    return;
  }
  await recordVisitEvent(state.activeVisitor.visit.visit_id, "fed", { item: "草莓" });
  showBubble(state.activeVisitor.element, "我会把草莓带回去。");
}

async function returnVisitor() {
  if (!state.activeVisitor) {
    addProtocolLog("当前没有来访宠物可以请回。");
    return;
  }
  const visitId = state.activeVisitor.visit.visit_id;
  await api(`/api/visits/${visitId}/end`, {
    method: "POST",
    body: JSON.stringify({
      reason: "host_requested_return",
      actor: { type: "host_user", user_id: userId }
    })
  });
  clearVisitors();
  addProtocolLog(`已请回来访宠物：${visitId}`);
}

function handleVisitStarted(payload) {
  clearVisitors();
  const { visit, profile } = payload;
  const rect = desktop.getBoundingClientRect();
  const element = createPetElement({
    profile,
    visitor: true,
    visit,
    x: Math.max(60, rect.width - 180),
    y: 180
  });
  state.activeVisitor = { visit, profile, element };
  showBubble(element, `我是 ${profile.name}，来你这里玩一会儿。`);
  addLifeLog(`${profile.name} 来你的桌面串门了。`);
  addProtocolLog(`收到 VisitSession：${visit.visit_id}`);
}

function handleMemoryReceipt(receipt) {
  $("#visit-status").textContent = `${state.localPet.name} 回家了。`;
  addLifeLog(receipt.life_log_entry);
  addLifeLog(receipt.pet_voice);
  addProtocolLog(`生成 MemoryReceipt：${receipt.receipt_id}`);
}

function connectEvents() {
  const source = new EventSource(`/events?user=${userId}`);
  source.addEventListener("open", () => {
    $(".status-dot").classList.add("connected");
    $("#connection-status").textContent = "已连接 Relay";
  });
  source.addEventListener("heartbeat", () => {
    $(".status-dot").classList.add("connected");
  });
  source.addEventListener("profile_registered", (event) => {
    const profile = JSON.parse(event.data);
    addProtocolLog(`Relay 确认 ${profile.name} 的名片`);
  });
  source.addEventListener("visit_started", (event) => {
    handleVisitStarted(JSON.parse(event.data));
  });
  source.addEventListener("visit_status", (event) => {
    const visit = JSON.parse(event.data);
    addProtocolLog(`串门状态：${visit.status}`);
  });
  source.addEventListener("interaction_event", (event) => {
    const interaction = JSON.parse(event.data);
    addProtocolLog(`收到远端互动事件：${interaction.type}`);
  });
  source.addEventListener("visit_ended", (event) => {
    const payload = JSON.parse(event.data);
    clearVisitors();
    addProtocolLog(`来访结束：${payload.reason}`);
  });
  source.addEventListener("memory_receipt", (event) => {
    handleMemoryReceipt(JSON.parse(event.data));
  });
  source.addEventListener("error", () => {
    $(".status-dot").classList.remove("connected");
    $("#connection-status").textContent = "Relay 重连中";
  });
}

function renderChrome() {
  $("#runtime-title").textContent = `${state.user.display_name} Runtime`;
  $("#desktop-owner").textContent = `${state.user.display_name} 的桌面`;
  $("#pet-name").textContent = state.localPet.name;
  $("#pet-personality").textContent = state.localPet.personality_card;
  $("#pet-preview").style.background = state.localPet.preview;
  $("#friend-select").innerHTML = state.friends.map((id) => `<option value="${id}">${id}</option>`).join("");
  createPetElement({ profile: state.localPet, x: 110, y: 360 });
  renderLogs();
}

async function boot() {
  const data = await api(`/api/bootstrap?user=${userId}`);
  state.user = data.user;
  state.friends = data.friend_ids;
  renderChrome();
  connectEvents();
  await registerProfile();
}

$("#register-profile").addEventListener("click", registerProfile);
$("#send-visit").addEventListener("click", sendVisit);
$("#feed-visitor").addEventListener("click", feedVisitor);
$("#return-visitor").addEventListener("click", returnVisitor);

boot().catch((error) => {
  $("#connection-status").textContent = error.message;
  addProtocolLog(error.message);
});
