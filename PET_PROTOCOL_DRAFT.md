# Pet Protocol Draft

## 1. 协议目标

Pet Protocol 定义桌面宠物如何被识别、投影、串门、互动和携带记忆回家。

第一版协议服务于一个最小真实串门闭环：

1. 主人主动派宠物去好友桌面。
2. Relay 创建一次临时串门会话。
3. 好友 Runtime 在本地安全投影来访宠物。
4. 好友与来访宠物真实互动。
5. 互动事件回传给主人 Runtime。
6. 主人 Runtime 将事件吸收成宠物记忆、生活日志和关系牵连。

核心原则：

- 服务器不维持宠物实例。
- 宠物权威状态保存在主人本地 Runtime。
- Relay 只维护连接、权限、会话、事件和轻量 profile 快照。
- 来访宠物不是远程代码，而是由宿主 Runtime 渲染的受控角色投影。

## 2. 核心对象

### 2.1 PetSourceOfTruth

`PetSourceOfTruth` 不是传输对象，而是主人本地 Runtime 中的完整宠物状态。

它包含：

- 完整人格设定
- 完整外观资源
- 行为规则
- 长期记忆
- 生活日志
- 关系图谱
- 当前状态
- Agent 改造记录

协议只需要承认它的存在，不要求 Relay 保存它。

### 2.2 PetProfile

`PetProfile` 是发布到 Relay 的轻量宠物名片。

它用于让好友 Runtime 识别和投影这只宠物。

示例结构：

```json
{
  "pet_id": "pet_momo",
  "owner_user_id": "user_alice",
  "profile_version": 12,
  "protocol_version": "0.1",
  "name": "Momo",
  "style": "pixel",
  "preview_image_url": "https://relay.example/assets/pet_momo/preview.png",
  "asset_manifest": {
    "url": "https://relay.example/assets/pet_momo/manifest.json",
    "hash": "sha256-abc123"
  },
  "personality_card": "一只慢热但好奇的小猫，喜欢在屏幕边缘观察。",
  "projection_capabilities": [
    "idle",
    "walk",
    "sleep",
    "react_to_click",
    "react_to_drag",
    "receive_gift"
  ],
  "updated_at": "2026-05-22T10:30:00+08:00"
}
```

`PetProfile` 里不放高频变化状态。出门时的临时心情、目的、携带物应该放到 `VisitSession` 中。

### 2.2.1 Pet Registration

宠物如果要串门，需要先在 Relay 上完成注册。

这里的“注册”不是在服务器上创建一个宠物实例，而是发布一份可被好友识别、验证和投影的 `PetProfile`。

注册的目的：

- 让 Relay 知道这只宠物属于哪个主人。
- 让好友 Runtime 能确认来访宠物身份。
- 让宿主 Runtime 知道该拉取哪个素材包。
- 让双方确认协议版本是否兼容。
- 让 Relay 能检查好友关系、禁访规则和自动来访权限。
- 让互动事件能被正确路由回主人 Runtime。

注册过程可以理解为：

1. 主人本地 Runtime 创建或更新宠物。
2. Runtime 生成新的 `PetProfile` 快照。
3. Runtime 将 `PetProfile` 发布到 Relay。
4. Relay 记录 `pet_id`、`owner_user_id`、`profile_version` 和投影所需摘要。
5. 好友 Runtime 在收到来访会话时，根据 `profile_version` 拉取或复用这份名片。

重要边界：

> 注册的是宠物名片，不是宠物真身。

Relay 不保存完整人格、完整记忆、关系图谱或实时行为状态。完整宠物仍然以主人本地 Runtime 为权威。

### 2.3 HostRules

`HostRules` 是宿主桌面对来访宠物的接待规则。

示例结构：

```json
{
  "host_user_id": "user_bob",
  "allow_friend_auto_visit": true,
  "allow_bubble_text": true,
  "allow_sound": false,
  "allow_record_interactions": true,
  "allow_pet_to_pet_interactions": true,
  "allow_gifts_to_return": true,
  "max_visit_minutes": 15,
  "movement_policy": "free_roam",
  "blocked_pet_ids": [],
  "muted_pet_ids": []
}
```

主人定义宠物是谁，宿主定义它在自己的桌面上能做什么。

### 2.4 VisitSession

`VisitSession` 表示一次串门。

它是临时会话，不是服务器上的宠物实例。

示例结构：

```json
{
  "visit_id": "visit_001",
  "pet_id": "pet_momo",
  "owner_user_id": "user_alice",
  "host_user_id": "user_bob",
  "profile_version": 12,
  "status": "active",
  "departure_context": {
    "mood": "curious",
    "intent": "play",
    "carried_items": [
      {
        "item_id": "item_star_sticker",
        "name": "星星贴纸"
      }
    ]
  },
  "started_at": "2026-05-22T10:35:00+08:00",
  "expires_at": "2026-05-22T10:50:00+08:00"
}
```

建议状态：

- `pending`：已创建，等待宿主 Runtime 接收
- `active`：来访投影已在宿主桌面运行
- `returning`：正在结束并回传事件
- `completed`：已结束
- `cancelled`：被取消或请回
- `failed`：因为离线、权限或网络失败

### 2.5 PetProjection

`PetProjection` 是宿主 Runtime 根据 `PetProfile`、`VisitSession` 和 `HostRules` 创建出来的本地投影。

它不是从主人电脑传来的可执行实例。

示例结构：

```json
{
  "projection_id": "projection_001",
  "visit_id": "visit_001",
  "pet_id": "pet_momo",
  "source_profile_version": 12,
  "rendered_by": "host_runtime",
  "effective_capabilities": [
    "idle",
    "walk",
    "sleep",
    "react_to_click",
    "react_to_drag",
    "receive_gift"
  ],
  "effective_rules": {
    "allow_bubble_text": true,
    "allow_sound": false,
    "movement_policy": "free_roam",
    "max_visit_minutes": 15
  },
  "local_state": {
    "position": {
      "x": 640,
      "y": 720
    },
    "animation": "idle",
    "mood_hint": "curious"
  }
}
```

`local_state` 可以由宿主 Runtime 本地维护，不必每帧同步到 Relay。

### 2.6 InteractionEvent

`InteractionEvent` 记录串门期间真实发生过的互动。

示例结构：

```json
{
  "event_id": "event_001",
  "visit_id": "visit_001",
  "pet_id": "pet_momo",
  "actor": {
    "type": "host_user",
    "user_id": "user_bob"
  },
  "type": "drag",
  "data": {
    "from": {
      "x": 300,
      "y": 500
    },
    "to": {
      "x": 900,
      "y": 120
    },
    "duration_ms": 1800
  },
  "created_at": "2026-05-22T10:39:00+08:00",
  "visibility": "owner_can_see"
}
```

常见事件类型：

- `arrived`
- `clicked`
- `dragged`
- `fed`
- `message`
- `gift_received`
- `bubble_replied`
- `pet_met_pet`
- `pet_stayed_near_pet`
- `host_requested_return`
- `visit_timeout`
- `departed`

`message` 表示用户给宠物留下的一句话。当前 MVP 只记录和转发留言，不要求宠物生成回复。来访宠物的留言放在 `VisitEvent.data.text` 中；本地宠物留言可以通过 Runtime 直接提交到 Relay 的宠物留言接口。

### 2.7 MemoryReceipt

`MemoryReceipt` 是主人 Runtime 吸收互动事件后生成的结果。

它不一定要回传给宿主，但可以用于生活日志、关系图谱和宠物表达。

示例结构：

```json
{
  "receipt_id": "memory_001",
  "visit_id": "visit_001",
  "pet_id": "pet_momo",
  "source_events": [
    "event_001",
    "event_002"
  ],
  "life_log_entry": "Momo 去了 Bob 的桌面，见到了小柚，并被轻轻拖到右上角待了一会儿。",
  "pet_voice": "我刚刚去了 Bob 那里。他把我放到右上角，我在那里看了好久。",
  "relationship_traces": [
    {
      "target_pet_id": "pet_yuzu",
      "type": "met",
      "delta": {
        "encounter_count": 1
      }
    }
  ],
  "created_at": "2026-05-22T10:52:00+08:00"
}
```

## 3. 串门流程

### 3.1 发布宠物名片

当本地宠物被创建或发生适合公开的变化时，主人 Runtime 发布新的 `PetProfile` 快照到 Relay。

这一步只更新轻量摘要，不同步完整宠物。

如果宠物从未发布过 `PetProfile`，Relay 不应该允许它发起真实串门。因为宿主 Runtime 无法验证它是谁，也无法安全创建投影。

### 3.2 主人发起串门

主人在本地 Runtime 选择好友，并主动派宠物出门。

Runtime 向 Relay 请求创建 `VisitSession`。

Relay 检查：

- 双方是否是好友
- 宿主是否在线
- 宿主是否允许好友自动来访
- 宠物 profile 是否可用
- 是否存在禁访、静音或数量限制

### 3.3 宿主接收投影

宿主 Runtime 收到 `VisitSession` 后：

1. 拉取或复用 `PetProfile`。
2. 校验素材 manifest 和版本。
3. 合并主人宠物能力与宿主规则。
4. 创建 `PetProjection`。
5. 在桌面显示来访宠物。
6. 向 Relay 确认 session 进入 `active`。

### 3.4 宿主互动

宿主用户和本地宠物可以与来访宠物互动。

宿主 Runtime 本地处理动画和即时反馈，并记录 `InteractionEvent`。

事件可以实时上传，也可以在串门结束时批量上传。第一版建议支持批量上传，减少实时同步压力。

### 3.5 宠物回家

串门结束可能由以下原因触发：

- 到达停留时间上限
- 宿主用户请回
- 主人召回
- 宿主 Runtime 退出
- 网络中断

结束时，宿主 Runtime 将事件上传到 Relay。Relay 再把事件转交给主人 Runtime。

主人 Runtime 根据完整宠物状态解释事件，生成 `MemoryReceipt`，并更新生活日志和关系图谱。

## 4. 同步策略

### 4.1 心跳同步

Runtime 定期向 Relay 发送心跳。

心跳内容应该轻量：

- 用户在线状态
- 设备连接状态
- 是否允许接待
- 当前活跃 visit session
- 本地 profile 版本

心跳不传完整宠物状态。

### 4.2 Profile 同步

`PetProfile` 采用版本号同步。

如果宿主 Runtime 缓存的 profile 版本低于 session 指定版本，就重新拉取。

如果拉取失败，可以拒绝来访或使用上一个可用版本，具体策略后续再定。

### 4.3 Event 同步

`InteractionEvent` 是串门记忆的基础。

第一版可以先采用“结束时批量上传 + 关键事件实时上传”的混合方式：

- 到达、请回、离开等关键事件实时上传。
- 点击、拖拽、停留等普通事件可以批量上传。

## 5. 安全边界

来访宠物不能：

- 读取宿主本地文件
- 读取宿主屏幕内容
- 操作宿主鼠标键盘
- 访问宿主本地网络资源
- 执行主人提供的任意代码
- 绕过宿主的静音、请回、禁访或记录规则

宿主 Runtime 对来访宠物拥有最终控制权。

## 6. 待讨论问题

- 好友关系如何建立和确认？
- 离线好友是否允许创建 pending visit？
- 宠物被请回时，给主人展示成什么体验？
- 来访宠物与本地宠物的互动，是纯 Runtime 规则驱动，还是可以调用本地 Agent 生成解释？
- 礼物是否需要独立协议对象？
- 素材包如何校验和缓存？
- 是否需要给互动事件设置隐私级别？
- 第一版是否允许多个来访宠物同时存在？
