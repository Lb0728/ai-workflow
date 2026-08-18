# AI Workflow

一个**通用 AI 编码工作流框架**：用状态机、门禁与证据协议，把"AI 写代码"从
自由发挥变成可治理、可恢复、可验证的工程过程。

- 机器级入口：`ai-workflow` CLI（init / new / next / finish / transition / assemble / doctor / feedback / build / package）
- 状态机唯一真源：`core/config/state-machine.yaml`（阶段、迁移、门禁、默认下一步全部声明式定义）
- 不绑定模型：Host Adapter（Codex / Cursor / Claude Code）只负责入口、权限与呈现，不选模型
- 项目事实隔离：Project Adapter 注入每个项目的真源、风险域与回归面，Core 保持通用
- 开源协议：MIT（见 [LICENSE](LICENSE)）

> 本仓库是 AI Workflow 的独立源码与分发目录，不属于任何业务项目。业务项目从
> 各自根目录执行 `ai-workflow init --host <host>` 安装使用，不保存本仓库副本。

---

## 1. 特性

| 特性 | 说明 |
|---|---|
| 声明式状态机 | 阶段别名、stage↔decision 映射、迁移表、每等级必需门禁、默认下一阶段全部定义在 `core/config/state-machine.yaml`，Router / finish / transition 共用同一份表 |
| Evidence First | 关键决策先以任务直接资料和真实实现为准；无证据只能写"假设"，禁止写"根因已确认" |
| 风险自适应 | 9 个布尔风险信号决定 L1/L2/L3 交付强度；上下文按等级裁剪（L1 不加载知识正文，L3 缺陷卡最多 5 张） |
| 门禁强制 | L0/L1/L2/L3 + 专项门禁，结果只能是 PASS / FAIL / NOT_RUN / N/A / BLOCKED；无证据不能进 READY_FOR_QA |
| 任务卡 Schema 校验 | `new` 创建即校验、`transition` 迁移前校验、`doctor` 全量扫描 |
| 不可变约束 | 禁止自动 Commit/Push、硬 Gate、STOP 条件——任何层不可覆盖 |
| Host / 模型无关 | Host Adapter 不选模型；换模型不改变 Router 状态、风险等级、门禁结果 |
| CI 护栏 | `ci/pipeline.sh` 六道门禁：语法、shellcheck、验收套件、分发包、clean worktree、artifact 一致性 |

## 2. 快速开始

### 2.1 安装（每台开发者机器一次）

```bash
# 从分发包解压并安装 CLI（macOS 或 WSL2）
./dist/install.sh --prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"

# 在目标项目根目录初始化（生成 .ai/ 状态并安装 Host 入口）
cd <target-project>
ai-workflow init --host codex        # 或 --host cursor

# 只读校验安装与任务卡
ai-workflow doctor
```

### 2.2 日常任务循环（AI 驱动）

**任务卡不是手工维护的文档，阶段推进不是手工敲命令。** `ai-workflow new`
建卡一次之后，整个循环由 AI（Codex / Cursor）自动驱动：AI 读取任务卡、执行
`next` 拿合法下一步、按 Agent 要求干活、把证据写回任务卡、执行 `finish`
收口，然后自动进入下一阶段。

开发者只做四件事：

```bash
# 1. 建任务卡（一句话让 AI 建，或自己敲；创建即做 Schema 校验）
ai-workflow new bugfix DEMO-101 typo P2 micro_change
ai-workflow new feature DEMO-102 help-support P1 light_feature
ai-workflow new device DEMO-103 d2-binding P1 high_risk_delivery

# 2. 把任务交给 AI：直接说“推进这个任务”，或先看一眼合法下一步
ai-workflow next <task-file>
```

```text
3. 在四个硬检查点介入（其余时间 AI 自动连续推进）：
   - high_risk_delivery 进入 IMPLEMENT 前：审核对齐包并明确确认
   - Self Test 需要真机 / 设备 / 账号 / 人工验证时：执行并回填
   - Review 通过后：执行人工提交（Commit Agent 只生成提交信息）
   - BLOCKED / STOP：解除唯一阻塞并指定恢复阶段
4. 不需要人工输入时，AI 直接继续下一阶段，不用等你说“继续”。
```

AI 自动循环内部实际执行的命令（无需人工敲）：

```bash
ai-workflow next <task-file>          # 拿阶段 / 门禁 / Agent / 上下文
ai-workflow assemble <agent> <task-file>   # 需要时取完整 Agent 上下文
ai-workflow finish <task-file>        # 校验并推进状态（非法迁移被拒绝）
ai-workflow next --apply <task-file>  # Bugfix 决策路由（迁移前 Schema 校验）
```

## 3. 架构

```text
┌─────────────────────────────────────────────────────────────┐
│                     业务项目（使用方）                         │
│   .ai/（init 生成）    AGENTS.md / .cursor/rules/...          │
│   .ai-runtime/（任务实例真源）                                 │
└───────────────▲──────────────────────────▲───────────────────┘
                │ symlink / 发现             │ 安装的 Workflow 包
┌───────────────┴──────────────────────────┴───────────────────┐
│  AI Workflow 仓库                                            │
│  ┌─ Host Adapter ──────────── hosts/<id>/host.yaml          │
│  │  指令入口、Skill 位置、权限模型、状态呈现；不选模型          │
│  ├─ CLI ───────────────────── cli/ai-workflow               │
│  │  init new next finish transition assemble doctor ...     │
│  ├─ Loader ────────────────── core/loader/                  │
│  │  按优先级装配上下文，检测不可变约束冲突                     │
│  ├─ Router / 状态机 ───────── core/router/ + core/config/   │
│  │  state-machine.yaml：阶段/迁移/门禁/默认下一步             │
│  ├─ Core ──────────────────── core/agents/（9 个 Agent）    │
│  │  workflows/ templates/ schemas/ lib/（sm_* / tc_*）      │
│  ├─ Project Adapter ───────── adapters/<id>/                │
│  │  project-profile.yaml + config/ + context/（项目事实）    │
│  ├─ Company Policy ────────── policies/company/             │
│  ├─ Role ──────────────────── roles/developer/              │
│  ├─ Discovery ─────────────── discovery/（栈检测与 profile） │
│  └─ CI ────────────────────── ci/pipeline.sh + GitHub Actions│
└─────────────────────────────────────────────────────────────┘
```

目录职责：

| 目录 | 职责 |
|---|---|
| `core/` | 唯一真源：agents（9 个）、config（core-defaults / state-machine / task-types）、loader、router、schemas、templates、workflows、lib |
| `adapters/<id>/` | Project Adapter：project-profile.yaml + config（commands/gates/risk-rules/commit…）+ context（真源/架构/回归面） |
| `hosts/` + `integrations/` | Host Adapter：codex / cursor / claude-code |
| `cli/` | `ai-workflow` 命令入口 |
| `discovery/` | 项目栈检测 + project-profile 生成 + schema 校验 |
| `skills/` | 5 个显式调用 Skill：grill-me / grill-with-docs / to-prd / to-task-cards / handoff |
| `policies/` `roles/` | Company Policy、Role 默认值 |
| `runtime/` `runtime-template/` | 任务实例布局（源码回退 / 分发包种子） |
| `tests/` | 验收测试套件（tests/run_all.sh） |
| `ci/` `.github/` | CI 管道与 GitHub Actions 工作流 |
| `docs/` | 使用文档、术语表、安装契约 |
| `examples/` | demo-project 示例与脱敏示例任务卡 |
| `compat/` | V1 兼容入口（已冻结，见 DEPRECATED.md） |

## 4. 核心概念

### 4.1 交付等级与风险强度

| delivery_level | 适用范围 | Gate |
|---|---|---|
| `micro_change` | 单句文案、单点样式、明确展示 Bug | L0 + 页面验证 |
| `light_feature` | 单页面、小功能、已有能力复用 | L0/L1/L2，L3 可 N/A 且说明原因 |
| `standard_delivery` | 多页面、接口、共享状态、普通功能链路 | L0/L1/L2/L3 + Review |
| `high_risk_delivery` | 设备、协议、并发、共享核心状态、迁移 | 完整治理 + `ALIGNMENT_PENDING` + 专项验证 |

Router 使用任务载体中的 9 个布尔风险信号（核心用户流、接口契约变更、共享状态、
多模块、多仓库、历史重复缺陷、影响范围不清、架构边界、真实设备/生产依赖）
判断最低合理强度；命中强制升级条件时必须 `ESCALATE`，禁止同级或降级。

### 4.2 状态机

- 17 个规范阶段（requirement_breakdown → analyze → impact_map → architecture /
  capability / alignment_pending → implement → ready_for_self_test →
  self_test_in_progress → review / ready_for_qa → commit_ready → done / blocked）
- 决策动作：`STAY / ADVANCE / RETURN / ESCALATE / STOP / COMPLETE`，迁移表声明在
  `core/config/state-machine.yaml`，Router、finish、transition 共用
- `ALIGNMENT_PENDING` 不是 `BLOCKED`：缺用户确认停在对齐；缺关键规则/设备/环境
  才进 `BLOCKED`

### 4.3 Loop Closeout（阶段收口）

每个阶段结束时，AI 必须在任务卡写入：

```text
## Loop Closeout
- 当前状态：<真实状态>
- 是否 Done：是 / 否
- Done 依据：<闭环证据>（非 Done 写 N/A）
- 唯一下一步：<一个可执行动作>（Done 写“无”）
- 是否需要 Owner 输入：是 / 否 + 原因
```

`READY_FOR_SELF_TEST`、`READY_FOR_QA`、`COMMIT_READY`、`BLOCKED` 默认都不是 DONE。

### 4.4 Bugfix 三分流

| 路径 | 条件 | 下一步 |
|---|---|---|
| `NEEDS_CLARIFICATION` | 现象/预期/范围不清 | 回到澄清 |
| `FAST_FIX` | 根因明确、局部改动 | 最小修复 + 针对性验证 |
| `STANDARD_FIX` | 状态流/多模块/接口 | 完整链路分析 + 回归 |
| `DIAGNOSTIC_LOOP` | 偶现、并发、协议、跨端、根因不明 | 六步闭环：复现→最小化→假设→观测→最小修复→回归证明 |

### 4.5 Skill（显式调用）

| Skill | 使用时机 | 产物 |
|---|---|---|
| `$grill-me` | 原始聊天、需求未收敛 | `CLARIFICATION_PENDING` |
| `$grill-with-docs` | 长期术语、跨模块边界、架构决策 | `CONTEXT.md` / ADR 候选 |
| `$to-prd` | 需求已确认 | PRD |
| `$to-task-cards` | PRD 已确认 | Task Card / Fast Brief 拆分 |
| `$handoff` | 会话中断、跨会话恢复 | `handoffs/` 恢复快照 |

## 5. 完整使用流程

见 [docs/V2_QUICKSTART.md](docs/V2_QUICKSTART.md)（安装/组装/回滚）与
README §2 的日常循环；术语中英对照见 [docs/GLOSSARY.md](docs/GLOSSARY.md)。

## 6. 配置与扩展

- **自定义 Project Adapter**：复制 `adapters/demo-project/`，修改
  `project-profile.yaml`（检测标记、必需配置/上下文）与 `config/`、`context/`
- **自定义分发**：复制 `distribution/example.yaml`，按
  [distribution/README.md](distribution/README.md) 校验与打包
- **修改状态机**：只改 `core/config/state-machine.yaml`，然后跑
  `tests/run_all.sh`（改状态规则不许改脚本）
- **任务卡 Schema**：`core/schemas/task-card.schema.yaml`（校验器
  `core/lib/task_card.sh`）

## 7. 测试与 CI

```bash
tests/run_all.sh                  # 25 项验收测试
bash ci/pipeline.sh               # 六道门禁（本地预检）
bash ci/pipeline.sh --require-shellcheck   # CI 强制模式
```

push / PR 到 `main` 自动触发 GitHub Actions（`.github/workflows/acceptance.yml`）。

## 8. 贡献指南

1. 分支从 `main` 切出，PR 合回 `main`（保持单主干）；
2. 改动必须通过 `tests/run_all.sh` 与 `ci/pipeline.sh --require-shellcheck`；
3. 状态机/词汇改动只改 `core/config/state-machine.yaml`；
4. 新增能力默认复用现有 9 个 Agent 与既有链路，不新增平行机制；
5. 提交信息遵循 `policies/company/commit-convention.yaml`（或项目自有规则）；
6. 真实项目事实、任务卡、门禁配置属于业务项目，不进本仓库（见
   `adapters/demo-project` 的定位）。

## 9. License

[MIT](LICENSE)
