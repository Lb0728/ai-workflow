# AI Workflow × DeepSeek Harness 集成

把 AI Workflow 作为 **dsh profile bundle 插件** 安装进 DeepSeek Harness：插件
注册一个打包 Skill Provider，向当前 profile 注入 6 个技能：

| Skill | 来源 | 用途 |
|---|---|---|
| `grill-me` | 仓库 `skills/grill-me` | 需求澄清门禁 |
| `grill-with-docs` | 仓库 `skills/grill-with-docs` | 长期术语/架构决策澄清 |
| `to-prd` | 仓库 `skills/to-prd` | 生成 PRD |
| `to-task-cards` | 仓库 `skills/to-task-cards` | PRD 拆任务卡 |
| `handoff` | 仓库 `skills/handoff` | 跨会话恢复快照 |
| `ai-workflow` | 本插件（meta skill） | 教 agent 用 `ai-workflow` CLI 驱动完整循环 |

前 5 个技能与仓库 `skills/` 同源（`prepack` 时由 `scripts/copy-skills.mjs` 同步），
`ai-workflow` 是本集成独有的元技能。

## 安装

前置：本机已安装 `dsh` CLI 与 `ai-workflow` CLI，且目标 profile 已初始化
（web 或 headless profile 首次使用自动初始化）。

### 方式 A：本地路径安装（不发布 npm，推荐先试）

```bash
cd <ai-workflow-checkout>
dsh plugin --profile web add file:./integrations/dsh
```

`dsh plugin --profile <name> <pnpm args>` 会把参数转发给 pnpm，安装后自动把
声明了 `dsh.bundle` 的包加入 profile 的 bundles 层栈。重启 web 会话后技能生效
（Skill 目录热加载依赖 profile 的 skill-filesystem watcher）。

### 方式 B：npm 发布后安装

```bash
dsh plugin --profile web add ai-workflow-dsh
```

### 卸载

```bash
dsh plugin --profile web remove ai-workflow-dsh
```

## 工作原理

- `package.json` 声明 `dsh.bundle.patch: ./cordis.patch.yml`，使本包成为
  dsh 的 profile bundle 层。
- `cordis.patch.yml` 只插入一行插件：`id: ai-workflow` → 本包自身。
- `lib/index.js` 是 Cordis 插件：`apply(ctx)` 调用
  `ctx.skills.registerProvider(...)` 注册名为 `ai-workflow` 的打包技能
  Provider，扫描 `./skills/*/SKILL.md`（frontmatter 需含 `name` + `description`）。
- 不触碰 `skill-filesystem` 行、agent instructions 或任何工具行：其余配置
  保持 base bundle 与用户 patch 层的原样。
- 技能在模型侧与用户侧都默认可调用（未设置 `disable-model-invocation`）。

## 开发与验证

```bash
node scripts/copy-skills.mjs     # 重新同步仓库 skills/ 到打包目录
node --check lib/index.js        # 插件语法
bash ../../tests/test_dsh_integration.sh   # 结构验证（随 CI 运行）
```

## 与 `ai-workflow init --host` 的关系

本插件是 DSH 侧的接入层。`ai-workflow` 仓库自身的 Host Adapter 机制
（`hosts/<host>/host.yaml`）面向 Codex / Cursor 等宿主；DSH 场景下技能由本
插件以 bundle 形式提供，任务卡与运行时仍由 `ai-workflow` CLI 管理。
