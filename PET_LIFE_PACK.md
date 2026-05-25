# Pet Life Pack

`Pet Life Pack` 是 Pet Skill 创造宠物后交给 Runtime 的生命包。

它不是单纯的皮肤，也不是一段远程代码。它是一组结构化设定，让 Runtime 能把一只宠物作为独立小生命运行起来。

## 1. 目标

Pet Life Pack 要解决三个问题：

1. 让 Agent 可以通过访谈生成宠物。
2. 让 Runtime 可以读取宠物，而不是把 Momo/Yuzu 写死在代码里。
3. 让后续行为、状态、记忆、串门偏好都能扩展。

## 2. 当前 MVP 文件

第一版先使用一个文件：

```text
life-packs/<pet-id>/pet-life.json
```

它包含：

- `profile`：注册到 Relay 的轻量宠物名片
- `voice`：宠物说话口吻
- `animation_states`：动作状态和 sprite sheet 规格
- `asset_prompts`：生成外观和动作素材的提示词
- `behavior`：基础状态和互动反应
- `memory_rules`：事件如何变成记忆的提示
- `visit_preferences`：串门偏好

## 3. 示例结构

```json
{
  "schema_version": "0.1",
  "profile": {
    "pet_id": "pet_momo",
    "owner_user_id": "alice",
    "profile_version": 1,
    "protocol_version": "0.1",
    "name": "Momo",
    "style": "pixel",
    "preview": "#6bc6a8",
    "personality_card": "慢热但好奇，喜欢被轻轻拖到新的观察点。",
    "projection_capabilities": [
      "idle",
      "walk",
      "sleep",
	    "react_to_click",
	    "react_to_drag",
	    "receive_gift"
	  ],
	  "interaction_capabilities": [
	    "petting",
	    "message",
	    "return_home",
	    "gift.simple",
	    "pet_to_pet.greeting",
	    "pet_to_pet.sit_together",
	    "pet_to_pet.walk_together"
	  ]
	},
  "voice": {
    "tone": "慢热、柔软、观察型",
    "first_person": true,
    "sample_lines": {
      "home_idle": "我在这里。",
      "clicked": "我在桌面上。",
      "dragged": "这里视野不错。",
      "visitor_arrived": "我是 Momo，来串门啦。",
      "fed": "我会把草莓带回去。"
    }
  },
  "animation_states": {
    "idle": {
      "description": "站着发呆，轻微呼吸感。",
      "asset": "assets/idle.png",
      "format": "sprite_sheet_png",
      "frame_width": 64,
      "frame_height": 64,
      "frames": 4,
      "fps": 6,
      "loop": true
    },
    "run": {
      "description": "小跑，耳朵和尾巴上下动。",
      "asset": "assets/run.png",
      "format": "sprite_sheet_png",
      "frame_width": 64,
      "frame_height": 64,
      "frames": 6,
      "fps": 10,
      "loop": true,
      "default_facing": "left"
    },
    "sleep": {
      "description": "趴着睡觉，有轻微呼吸感。",
      "asset": "assets/sleep.png",
      "format": "sprite_sheet_png",
      "frame_width": 64,
      "frame_height": 64,
      "frames": 3,
      "fps": 2,
      "loop": true
    },
    "carry_ball": {
      "description": "叼着皮球走过来。",
      "asset": "assets/carry_ball.png",
      "format": "sprite_sheet_png",
      "frame_width": 64,
      "frame_height": 64,
      "frames": 6,
      "fps": 8,
      "loop": false
    }
  },
  "asset_prompts": {
    "style_prompt": "像素风桌面宠物，透明背景，清晰轮廓，有限色板，64x64 单帧规格。",
    "state_prompts": {
      "run": "同一只宠物的 6 帧横向 sprite sheet，小跑动作，透明背景。",
      "sleep": "同一只宠物的 3 帧横向 sprite sheet，趴着睡觉，轻微呼吸感，透明背景。",
      "carry_ball": "同一只宠物的 6 帧横向 sprite sheet，叼着皮球走来，透明背景。"
    }
  },
  "behavior": {
    "home_states": ["idle", "sleepy", "curious"],
    "away_states": ["departing", "visiting", "returning"],
    "state_transitions": [
      {
        "from": "idle",
        "to": "run",
        "trigger": "move_to_target"
      },
      {
        "from": "idle",
        "to": "sleep",
        "trigger": "inactive_for_10_minutes"
      },
      {
        "from": "visit_returned",
        "to": "carry_ball",
        "trigger": "returned_with_gift:ball"
      }
    ],
    "interactions": {
      "click": {
        "reaction": "bubble",
        "memory_weight": "low"
      },
      "drag": {
        "reaction": "bubble",
        "memory_weight": "medium"
      },
      "feed": {
        "reaction": "bubble",
        "memory_weight": "high"
      },
      "fetch_ball": {
        "trigger": "interaction_menu:throw_ball",
        "sequence": [
          "throw_ball_far",
          "move_to_target_scale_down",
          "pick_up_ball",
          "return_with_ball_scale_up",
          "rest"
        ],
        "reaction": "movement_animation",
        "memory_weight": "high"
      }
    }
  },
  "memory_rules": {
    "summary_style": "把事件整理成第一人称的小经历，不要像系统日志。",
    "remember_events": ["dragged", "fed", "host_runtime_offline", "host_requested_return"]
  },
  "visit_preferences": {
    "likes_visiting": true,
    "default_intent": "play",
    "default_mood": "curious",
    "carried_items": []
  }
}
```

## 4. 设计原则

- 生命包是数据，不是可执行代码。
- Runtime 负责执行和安全边界。
- Skill 负责生成和改造生命包。
- Relay 只保存 `profile` 快照，不保存完整生命包。
- 宠物的完整生命包和记忆应该保存在主人本地。
- 动画推荐使用 sprite sheet PNG，而不是 APNG/GIF。普通 PNG 不会自己动，但可以承载多帧素材，由 Runtime 按帧播放。
- `idle` / `rest` / `sleep` 等静态或弱动画状态必须保持主体视觉尺寸和锚点稳定。落地宠物保持脚底/身体基线一致；漂浮或无方向宠物保持中心点一致。不要通过整只宠物逐帧缩放、重新居中来制造呼吸感，否则桌面上会产生大小抖动。
- 移动类 sprite sheet 需要有统一朝向。`default_facing` 可选值为 `right`、`left`、`none`；缺省为 `right`。`move` / `run` / `walk` / `hop` 推荐默认面向右，Runtime 会根据移动方向和素材默认朝向决定是否水平翻转。正面或无明显朝向的状态使用 `none`。同一张 sprite sheet 里不要混用左右朝向。
- 复杂互动可以由多个动作语义组成。比如捡球不是单个 `carry_ball`，而是 `throw_ball_far -> move_to_target_scale_down -> pick_up_ball -> return_with_ball_scale_up -> rest`。这只是小狗案例，不是所有宠物的默认动作。
- Runtime 可以在 sprite sheet 之外叠加空间效果，例如位置移动、缩放、气泡和道具窗口；生命包负责描述意图，Runtime 负责安全执行。
- `interaction_capabilities` 用来声明来访时可接受的互动。Runtime 应只展示双方都支持的互动；旧生命包未声明时默认只支持 `petting`、`message`、`return_home`。基础宠物间互动包括 `pet_to_pet.greeting`、`pet_to_pet.sit_together` 和 `pet_to_pet.walk_together`，Runtime 可以用 `idle` / `rest` / `move` 组合出默认效果，不要求每个宠物都单独画专属素材。

## 5. Runtime 动作意图

Runtime 不应该假设所有宠物都会跑、坐下或叼球。它会先表达动作意图，再从生命包里找合适的动作状态：

- `move`：移动意图。优先使用 `move`，旧宠物可 fallback 到 `run` / `walk` / `float`。
- `rest`：安静停留或被摸后的状态。优先使用 `rest`，旧宠物可 fallback 到 `sit` / `idle`。
- `sleep`：睡觉或休息。
- `signature_*`：宠物自己的招牌动作，例如 `signature_glow`。
- `return_with_gift`：带东西回来。小狗案例可 fallback 到 `carry_ball`。

Skill 生成新宠物时，优先使用通用动作名：`idle`、`move`、`rest`、`sleep`、`signature_xxx`。

## 6. 基础互动能力

第一版生命包应该优先具备这些可跨宠物形态复用的互动能力：

- `petting`：被宿主用户摸摸。Runtime 可用轻微弹跳和 `rest` 表达。
- `message`：宿主用户给来访宠物留言，事件会带回给主人。
- `return_home`：宿主可以把来访宠物送回家。
- `pet_to_pet.greeting`：本地宠物和来访宠物互相打招呼。
- `pet_to_pet.sit_together`：来访宠物靠近本地宠物，一起安静待一会儿。
- `pet_to_pet.walk_together`：两只宠物一起从桌面一处移动到另一处。

## 7. 后续扩展

后续可以拆成多个文件：

```text
pet-life.json
appearance-prompts.md
voice.md
behavior.json
memory-rules.md
assets/
```

也可以加入：

- 更完整的多动作素材 manifest
- 风格生成提示词
- 更复杂状态机
- 与其他宠物的关系偏好
- 主动串门规则
- 离线生活规则
