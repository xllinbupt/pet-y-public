import fs from "node:fs";
import path from "node:path";

const args = parseArgs(process.argv.slice(2));
const repoRoot = process.cwd();
const name = args.name ?? "Milo";
const owner = args.owner ?? "local";
const style = args.style ?? "pixel";
const form = args.form ?? args.species ?? "桌面小伙伴";
const signature = args.signature ?? "greet";
const petId = args["pet-id"] ?? `pet_${slug(name)}`;
const outputDir = path.resolve(repoRoot, args.output ?? `life-packs/${slug(name)}`);
const personality = args.personality ?? "亲人、好奇，喜欢在桌面上陪着你。";
const tone = args.tone ?? "温柔、简短、像一个会回应你的小生命";
const preview = args.preview ?? "#d9a45f";
const signatureState = signatureStateFor(signature);
const animationStates = buildAnimationStates(signatureState);
const statePrompts = buildStatePrompts(style, form, signature, signatureState);
const interactions = buildInteractions(signature, signatureState);

if (style !== "pixel") {
  throw new Error("MVP generator currently supports --style pixel only.");
}

fs.mkdirSync(path.join(outputDir, "assets"), { recursive: true });

const lifePack = {
  schema_version: "0.1",
  profile: {
    pet_id: petId,
    owner_user_id: owner,
    profile_version: 1,
    protocol_version: "0.1",
    name,
    style,
    preview,
    personality_card: personality,
    projection_capabilities: [
      "idle",
      "move",
      "rest",
      "sleep",
      signatureState,
      "react_to_click",
      "react_to_drag",
      "receive_gift"
    ],
    interaction_capabilities: [
      "petting",
      "message",
      "return_home",
      "gift.simple",
      "pet_to_pet.walk_together"
    ]
  },
  voice: {
    tone,
    first_person: true,
    sample_lines: {
      home_idle: "我在这里。",
      clicked: "我在！",
      dragged: "这个地方也可以。",
      visitor_arrived: `我是${name}，我来串门啦。`,
      fed: "我会把这个好吃的带回去。",
      signature: "我想给你看我的小动作。"
    }
  },
  animation_states: animationStates,
  asset_prompts: {
    style_prompt: `${styleLabel(style)}${form}桌面宠物，64x64 单帧规格，透明背景，清晰轮廓，有限色板，动作帧一致。`,
    state_prompts: statePrompts
  },
  behavior: {
    home_states: ["idle", "rest", "sleep"],
    away_states: ["departing", "visiting", "returning"],
    state_transitions: [
      { from: "idle", to: "move", trigger: "move_to_target" },
      { from: "idle", to: "rest", trigger: "user_nearby" },
      { from: "idle", to: "sleep", trigger: "inactive_for_10_minutes" },
      { from: "idle", to: signatureState, trigger: "interaction_menu:signature" }
    ],
    interactions
  },
  memory_rules: {
    summary_style: "用宠物自己的口吻，把互动整理成一小段生活经历，不要像系统日志。",
    remember_events: ["dragged", "fed", "host_runtime_offline", "host_requested_return"]
  },
  visit_preferences: {
    likes_visiting: true,
    default_intent: "play",
    default_mood: "curious",
    carried_items: signature === "fetch_ball" ? ["ball"] : []
  }
};

writeJson(path.join(outputDir, "pet-life.json"), lifePack);
writePrompts(path.join(outputDir, "appearance-prompts.md"), lifePack);
writeAssetTasks(path.join(outputDir, "asset-generation-tasks.md"), lifePack);

console.log(`Created ${path.relative(repoRoot, outputDir)}`);
console.log(`Next: generate model-made sprite sheets from ${path.relative(repoRoot, path.join(outputDir, "asset-generation-tasks.md"))}`);
console.log(`Run with: PET_Y_LIFE_PACK=${path.relative(repoRoot, path.join(outputDir, "pet-life.json"))} ./scripts/run-desktop.sh`);

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}

function animationState(description, asset, frames, fps, loop) {
  return {
    description,
    asset,
    format: "sprite_sheet_png",
    frame_width: 64,
    frame_height: 64,
    frames,
    fps,
    loop
  };
}

function buildAnimationStates(signatureState) {
  return {
    idle: animationState("待机，有轻微呼吸感或小幅摆动。", "assets/idle.png", 4, 6, true),
    move: animationState("移动到目标位置，保持角色身份一致。", "assets/move.png", 6, 7, true),
    rest: animationState("安静停留或坐下，看向用户。", "assets/rest.png", 3, 4, true),
    sleep: animationState("进入休息或睡觉状态，有轻微呼吸感。", "assets/sleep.png", 3, 2, true),
    [signatureState]: animationState("招牌互动动作。", `assets/${signatureState}.png`, 6, 6, false)
  };
}

function buildStatePrompts(style, form, signature, signatureState) {
  const label = `${styleLabel(style)}${form}`;
  return {
    idle: `同一只${label}的 4 帧横向 sprite sheet，待机状态，轻微呼吸感或小幅摆动，透明背景。`,
    move: `同一只${label}的 6 帧横向 sprite sheet，移动动作，角色身份保持一致，透明背景。`,
    rest: `同一只${label}的 3 帧横向 sprite sheet，安静停留或坐下，看向用户，透明背景。`,
    sleep: `同一只${label}的 3 帧横向 sprite sheet，休息或睡觉状态，轻微呼吸感，透明背景。`,
    [signatureState]: signaturePrompt(label, signature)
  };
}

function signaturePrompt(label, signature) {
  if (signature === "fetch_ball") {
    return `同一只${label}的 6 帧横向 sprite sheet，带着或叼着红色皮球回到用户面前，透明背景。`;
  }
  if (signature === "dance") {
    return `同一只${label}的 6 帧横向 sprite sheet，小幅跳舞或开心摆动，透明背景。`;
  }
  if (signature === "glow") {
    return `同一只${label}的 6 帧横向 sprite sheet，身体轻轻发光或闪烁，透明背景。`;
  }
  if (signature === "hide") {
    return `同一只${label}的 6 帧横向 sprite sheet，害羞地躲起来又探头，透明背景。`;
  }
  return `同一只${label}的 6 帧横向 sprite sheet，表现一个独特但克制的招牌互动动作，透明背景。`;
}

function buildInteractions(signature, signatureState) {
  const base = {
    click: { reaction: "bubble", memory_weight: "low" },
    drag: { reaction: "bubble", memory_weight: "medium" },
    feed: { reaction: "bubble", memory_weight: "high" },
    pet: {
      trigger: "interaction_menu:pet",
      sequence: ["rest", "bubble_response"],
      reaction: "affection_animation",
      memory_weight: "medium"
    },
    sleep_now: {
      trigger: "interaction_menu:sleep",
      sequence: ["sleep"],
      reaction: "state_change",
      memory_weight: "low"
    }
  };

  if (signature === "fetch_ball") {
    base.fetch_ball = {
      trigger: "interaction_menu:throw_ball",
      sequence: [
        "throw_ball_far",
        "move_to_target_scale_down",
        "pick_up_ball",
        "return_with_ball_scale_up",
        "rest"
      ],
      reaction: "movement_animation",
      memory_weight: "high"
    };
  } else {
    base.signature = {
      trigger: "interaction_menu:signature",
      sequence: [signatureState, "bubble_response"],
      reaction: "signature_animation",
      memory_weight: "medium"
    };
  }

  return base;
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function writePrompts(filePath, pack) {
  const sections = Object.entries(pack.asset_prompts.state_prompts)
    .map(([key, prompt]) => `## ${titleCase(key)}\n\n${prompt}`)
    .join("\n\n");

  fs.writeFileSync(filePath, `# ${pack.profile.name} Appearance Prompts

## Style

${pack.asset_prompts.style_prompt}

${sections}
`);
}

function writeAssetTasks(filePath, pack) {
  const states = pack.animation_states;
  const prompts = pack.asset_prompts.state_prompts;
  const lines = [
    `# ${pack.profile.name} Asset Generation Tasks`,
    "",
    "Use an image model to generate these sprite sheets. Do not draw the pet with code.",
    "",
    "First generate or choose a character reference that establishes the pet's look. After the user approves the reference, generate each action sprite sheet with the same character identity.",
    "",
    "General constraints:",
    "",
    "- Pixel art desktop pet.",
    "- Transparent background, or flat chroma-key background for local background removal.",
    "- One horizontal sprite sheet per action.",
    "- Every frame must be 64x64 after processing.",
    "- Keep the same pet identity across all actions.",
    "- Movement sheets such as move, run, walk, or hop should face right; Runtime flips them when the pet moves left.",
    "- No text, watermark, shadows, floor, or background props.",
    "",
    "Tasks:",
    ""
  ];

  for (const key of Object.keys(states)) {
    const state = states[key];
    lines.push(`## ${key}`);
    lines.push("");
    lines.push(`- Output: \`${state.asset}\``);
    lines.push(`- Frames: ${state.frames}`);
    lines.push(`- Runtime size: ${state.frame_width}x${state.frame_height} per frame`);
    lines.push(`- FPS: ${state.fps}`);
    lines.push(`- Loop: ${state.loop}`);
    lines.push(`- Prompt: ${prompts[key]}`);
    lines.push("");
  }

  lines.push("Validation:");
  lines.push("");
  lines.push("- Character still looks like the approved reference.");
  lines.push("- Motion reads clearly at desktop pet scale.");
  lines.push("- Sheet dimensions match `frames * 64` by `64` after processing.");
  lines.push("- Corners are transparent.");
  lines.push("- User approves the look before promoting the result as a reusable Skill example.");
  lines.push("");

  fs.writeFileSync(filePath, lines.join("\n"));
}

function slug(value) {
  const normalized = value
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-");
  return normalized || `pet-${Date.now()}`;
}

function styleLabel(value) {
  return value === "pixel" ? "像素风" : value;
}

function signatureStateFor(value) {
  if (value === "fetch_ball") return "carry_ball";
  return `signature_${slug(value).replace(/-/g, "_")}`;
}

function titleCase(value) {
  return value
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}
