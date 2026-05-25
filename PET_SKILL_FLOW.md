# Pet Skill Flow

Pet Skill 的目标不是生成一个固定宠物，而是引导用户创造一只可运行、可持续改造、能串门的桌面宠物生命。

## 1. Skill 的角色

Pet Skill 是生命生成器。

它负责：

- 访谈用户
- 生成宠物生命包
- 生成或引用外观素材
- 生成 Relay 需要的 `PetProfile`
- 让 Runtime 读取生命包运行宠物
- 后续根据用户要求改造宠物

Runtime 是生命容器。Relay 是通信层。Skill 是创造过程。

## 2. 访谈原则

不要一次问太多。每轮只推进一个关键维度。

建议顺序：

1. 风格
2. 形态
3. 性格
4. 基础动作状态
5. 桌面陪伴方式
6. 人宠互动
7. 串门偏好
8. 记忆和说话口吻

## 3. 第一轮访谈

先问：

> 你想要它更像什么风格？像素风、手绘贴纸风、仿真毛绒 / 真实风，还是别的感觉？

根据用户回答选择风格预设。

## 4. 风格预设

### 4.1 像素风

提示词重点：

- 清晰轮廓
- 小尺寸桌面精灵
- 有限色板
- 透明背景
- 动作帧一致
- 适合悬浮在桌面边缘
- sprite sheet 横向排列，每一帧尺寸一致
- 静态状态锁定主体尺寸和锚点，避免待机时整只宠物忽大忽小

### 4.2 手绘贴纸风

提示词重点：

- 治愈、柔软
- 贴纸感边缘
- 清楚表情
- 透明背景
- 适合气泡表达

### 4.3 仿真毛绒 / 真实风

提示词重点：

- 毛绒材质
- 柔和光照
- 小玩偶比例
- 不要复杂背景
- 保持姿态一致

## 5. 生命包生成

访谈结束后，Skill 生成：

```text
life-packs/<pet-id>/pet-life.json
```

当前项目里已经有一个最小生成脚手架：

```bash
npm run create:pet -- --name Luma --pet-id pet_luma --style pixel --form "会发光的小星星" --signature glow --personality "安静、贴心，会在你分心时轻轻闪一下"
```

生成后可以用桌面 Runtime 直接启动：

```bash
PET_Y_LIFE_PACK=life-packs/luma/pet-life.json ./scripts/run-desktop.sh
```

Runtime 第一次启动会自动创建本机身份，Skill 不需要让普通用户理解 `alice / bob`。如果要和真实朋友测试串门，两边使用同一个公网 Relay：

```bash
PET_Y_RELAY=http://your-relay-host:8787 PET_Y_LIFE_PACK=life-packs/luma/pet-life.json ./scripts/run-desktop.sh
```

两边上线后，通过菜单栏复制邀请码、输入对方邀请码来建立好友关系。建立好友后，点击宠物下面的快捷互动，选择 `串门`。

生成脚手架会创建素材任务清单：

```text
asset-generation-tasks.md
```

素材应该由图像模型生成，而不是用代码画。正确流程是：先生成角色基准图，让用户确认这只宠物好看；再基于同一个角色生成 `idle / move / rest / sleep / signature action` 等动作 sprite sheet；最后切帧、透明化、验收并放进 `assets/`。

第一版至少要包含：

- `profile`
- `voice`
- `animation_states`
- `asset_prompts`
- `behavior`
- `memory_rules`
- `visit_preferences`

动作状态也是生命包的一部分，不是 Runtime 里写死的装饰。Skill 至少要为第一版宠物生成或引用这些内容：

- 待机状态：宠物平时怎么站着、呼吸、眨眼或摇尾巴。
- 移动状态：根据形态生成，可以是跑、走、飘、滚、跳、滑行、闪烁位移等。
- 休息状态：根据形态生成，可以是坐下、趴下、漂浮静止、收拢、熄灯、折叠等。
- 互动状态：被摸、被拖拽、被投喂、发光、躲藏、跳舞、送小礼物、叼东西回来等。
- 空间效果：例如跑远变小、飘近变亮、躲到屏幕边缘、围着鼠标绕一圈。

这些状态应该进入 `animation_states`、`asset_prompts` 和 `behavior.interactions`，让 Runtime 读取生命包后执行，而不是每次都改 Runtime 代码。

## 6. 实例反哺 Skill

当 Skill 和用户共同生成一个质量较好的宠物实例时，应该把它沉淀为风格案例。

比如用户生成了一个质量较好的像素风小狗，可以沉淀到：

```text
skill-presets/styles/pixel/examples/pixel-dog/
  pet-life.json
  appearance-prompts.md
  animation-states.json
  notes.md
```

以后别的用户选择像素风时，Skill 可以参考这些案例，让生成结果在轮廓、色板、动作帧、透明背景和桌面尺度上更稳定。

实例沉淀不只保存外貌，也要保存动作语义。比如像素风小狗的 `fetch_ball` 可以沉淀为：

```text
throw_ball_far -> move_to_target_scale_down -> pick_up_ball -> return_with_ball_scale_up -> rest
```

这样后续生成新的像素风小狗时，Skill 知道“捡球”不是一个单帧表情，而是一段完整动作。

但不要把这个案例当作所有宠物的默认动作。一个发光星星、一本会打哈欠的书、一个桌面小云朵，都应该拥有符合自己形态的动作集。

## 7. 改造宠物

后续用户可以继续说：

- 让它更害羞一点
- 给它加一个睡觉状态
- 它去别人桌面时不要太吵
- 它收到草莓时要更开心
- 它回家后说话更像小朋友

Skill 应该修改生命包，而不是直接改 Runtime 代码。
