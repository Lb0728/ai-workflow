# AI Tool README

本文件只记录 `ai/tool/` 下脚本的真实用法。工作流判断、场景选择和 Gate 规则见 [../README.md](../README.md)。

## 1. 使用纪律

- 运行任何脚本前，先遵守根目录 [../../AGENTS.md](../../AGENTS.md)。
- 脚本只生成任务载体、状态报告或可复制 Prompt，不替 Owner 决定是否实现、提测或提交。
- `ai_loop_next.sh` 输出的 Prompt 需要和对应 Agent / Task Card 一起给 Codex 使用。
- Agent 执行完当前阶段后，默认应根据任务载体和 Gate 主动进入下一个合法阶段；不要把脚本输出的 Prompt 当成必须等待 Owner 再说“继续”的停止点。
- 阶段收尾必须写清：当前完成内容、下一阶段名称、下一步是否合法、是否已继续执行；如果未继续，只写唯一阻塞点。
- high_risk_delivery 未确认前，请求 `implement` 会被拦截到 `alignment_pending`。
- Commit 阶段只生成提交信息，等待人工提交；脚本和 Commit Agent 都不应自动执行 git 提交。

## 2. install_ai_agent.sh

用途：从同一个版本化分发包为当前项目安装 AI workflow。脚本自动识别
Project Adapter，链接项目 `ai` 入口，把同一份 Skill 真源安装到所选客户端，
安装 Cursor / Claude Code 所需的最小项目规则，并创建项目独立
`.ai-runtime/`。

```bash
bash /path/to/package/tool/install_ai_agent.sh \
  --client <codex|cursor|claude-code> \
  [--project-root /path/to/project]
```

推荐由使用者先进入自己的项目根目录，因此不需要知道创建者电脑上的绝对路径：

```bash
cd /path/to/your/project
bash /path/to/package/tool/install_ai_agent.sh --client cursor
```

客户端 Skill 目标：

```text
Codex       ~/.agents/skills/<skill>
Cursor      ~/.cursor/skills/<skill>
Claude Code ~/.claude/skills/<skill>
```

项目安装入口：

```text
<project_repo_path>/ai -> <当前解压后的版本化分发包>
<project_repo_path>/.ai-runtime/ -> 当前项目私有的 task / state / handoff
```

Cursor 和 Claude Code 的常驻规则只在所选客户端安装。安装器把本地生成入口写入
`.git/info/exclude`，不会修改项目 `.gitignore`，也不会覆盖已有普通文件。
如果项目缺少 `AGENTS.md` 且选中的 Adapter 提供默认项目规则，安装器只在缺失时
创建本地链接；已有 `AGENTS.md` 始终保留。

解压后的包目录必须保持在稳定位置，因为项目入口和客户端 Skill 都链接到该目录。
移动、删除或升级包后，从新的包路径重新运行安装器。

`install_skills.sh` 仅保留为旧 Codex 安装方式；新试用统一使用
`install_ai_agent.sh`。安装完成后重新打开客户端会话。

## 2.1 AI Core Loader 与兼容检查

Phase 4 的 Loader 解析 Core、Project Adapter、Role 和 Runtime 路径，并为全部 Agent 装配所需上下文；它不执行项目命令。

```bash
./ai/tool/ai_core_loader.sh \
  --project-root /path/to/project \
  describe

./ai/tool/ai_core_loader.sh \
  --project-root /path/to/project \
  resolve runtime.tasks
```

迁移兼容检查：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./ai/tool/ai_core_compat_check.sh --project-root /path/to/project
```

该检查会验证 canonical owner、旧路径相对链接和 Loader 解析结果，不修改任何文件。

内部开发分发前再运行：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./ai/tool/ai_distribution_check.sh \
    --manifest example \
    --role developer
```

正式分发边界见 `distribution/example.yaml`；分发清单可按项目自定义。
Runtime 任务历史不进入分发包。

## 2.2 生成开发试用分发包

用途：根据选定分发清单，从已提交且干净的 Git 状态生成不含 `.git` 和 Runtime
历史的可验证压缩包。

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./tool/ai_distribution_package.sh \
    --project-root /path/to/project \
    --distribution example \
    --role developer \
    --output-dir /path/to/output
```

产物：

```text
<package-id>-developer-<commit>.tar.gz
<package-id>-developer-<commit>.tar.gz.sha256
```

生成前要求：

- AI 工作流仓库必须是 Git 仓库；
- 工作区必须干净；
- 必须显式指定统一 Distribution，或使用旧版单 Adapter 入口；
- 清单中的 include 必须都存在于选定 commit；
- 输出目录不得已经存在同名产物。

生成器只打包分发清单声明的已提交路径，然后创建空白 Runtime，并在压缩前执行
Doctor、兼容检查、分发检查和 Developer Pilot Check。`--project-root` 只用于
生成时验证自动识别和项目兼容性，不会写入包，也不会限制使用者的项目路径。
生成器不会删除或覆盖已有产物。

打包器回归测试：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  bash tool/test_ai_distribution_package.sh \
    examples/demo-project
```

安装器隔离回归：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  bash tool/test_ai_install.sh
```

## 3. ai_loop_new.sh

用途：创建新的 Task Card / Fast Brief / Micro Change 载体，并按交付等级初始化字段。

```bash
./ai/tool/ai_loop_new.sh <task-type> <task-id> [slug] [priority] [delivery_level]
```

参数：

| 参数 | 说明 |
|---|---|
| `type` | Core 类型与当前 Project Adapter 扩展类型；`adapters/demo-project` 额外声明 `docs` 类型作为示例 |
| `task-id` | JIRA 或任务编号，会用于生成文件名 |
| `slug` | 可选短标识；缺省时按任务编号生成 |
| `priority` | 可选，当前脚本识别 `P0`、`P1`、`P2` |
| `delivery_level` | 可选，`micro_change`、`light_feature`、`standard_delivery`、`high_risk_delivery` |

兼容别名：

| 输入 | 归一化结果 |
|---|---|
| `micro`、`tiny` | `micro_change` |
| `light`、`lite`、`quick`、`fast`、`fast_track`、`fast-track` | `light_feature` |
| `standard`、`normal`、`controlled`、`control` | `standard_delivery` |
| `high`、`heavy`、`high_risk`、`high-risk` | `high_risk_delivery` |

示例：

```bash
./ai/tool/ai_loop_new.sh bugfix DEMO-1234 typo P2 micro_change
./ai/tool/ai_loop_new.sh feature DEMO-4567 help-support P1 light_feature
./ai/tool/ai_loop_new.sh feature DEMO-4568 training-entry P1 standard_delivery
./ai/tool/ai_loop_new.sh device DEMO-7890 d2-binding P1 high_risk_delivery
```

输出：

- `micro_change` 使用 Loader 解析出的 `core.template.micro_change`。
- `light_feature` 使用 Loader 解析出的 `core.template.fast_brief`。
- `standard_delivery` / `high_risk_delivery` 使用 Loader 解析出的 `core.template.task_card`。
- high_risk_delivery 会自动写入 `alignment_required: true`、`alignment_status: pending`。
- Bugfix 即使是 `micro_change` 也从 `analyze` 开始填写证据决策；其他明确的 micro change 保持从 `implement` 开始。

## 4. ai_loop_status.sh

用途：读取任务载体，展示当前状态、Gate、对齐状态、自测证据和合法下一步。

```bash
./ai/tool/ai_loop_status.sh <task-or-brief-path>
```

示例：

```bash
./ai/tool/ai_loop_status.sh <runtime-task>
```

输出重点：

- 任务类型、业务优先级、交付等级、自测等级。
- 高风险对齐状态和是否允许 `IMPLEMENT`。
- 已完成、缺失、失败或阻塞的 Gate。
- Self Test、自动检查、人工验证、未测风险。
- `ai_loop_next.sh` 计算出的合法下一步和禁止原因。
- 当前 `Next Action` 是否是可执行承接动作；如果只是“继续下一步”，需要先改写成具体阶段、具体 Agent 和最小动作。

旧高风险任务卡如果没有 alignment 字段，脚本会按 `high_risk_delivery` 推断为：

```text
alignment_required: true
alignment_status: pending
```

## 5. ai_loop_next.sh

用途：根据任务载体和目标阶段生成下一步 Prompt，并拦截不合法阶段。

```bash
./ai/tool/ai_loop_next.sh <task-file> [stage]
```

当前脚本声明的阶段：

```text
requirement_breakdown
analyze
impact_map
architecture
capability
alignment_pending
fix_ready
implement
ready_for_self_test
validation_pending
self_test
review
commit_ready
ready_for_qa
i18n
done
commit
blocked
```

常用别名：

| 输入 | 归一化结果 |
|---|---|
| `impact`、`impact-map`、`plan` | `impact_map` |
| `arch`、`architecture-check` | `architecture` |
| `strategy`、`capability-check` | `capability` |
| `alignment`、`align`、`confirm`、`confirmation` | `alignment_pending` |
| `fix`、`fix-ready` | `fix_ready` |
| `coding`、`code` | `implement` |
| `verify`、`test`、`selftest`、`self-test` | `self_test_in_progress` |
| `validation`、`validation-pending` | `validation_pending` |
| `pr-review` | `review` |
| `ready`、`qa`、`ready-for-qa` | `ready_for_qa` |
| `commit`、`commit-ready`、`generate-commit-message` | `commit_ready` |

示例：

```bash
./ai/tool/ai_loop_next.sh <runtime-task>
./ai/tool/ai_loop_next.sh <runtime-task> impact_map
./ai/tool/ai_loop_next.sh <runtime-task> implement
./ai/tool/ai_loop_next.sh <runtime-task> commit_ready
```

高风险拦截：

- `delivery_level=high_risk_delivery` 且 `alignment_status != confirmed` 时，请求 `implement` 会被拦截。
- 实际输出阶段会变为 `alignment_pending`。
- Agent 会变为 Architecture Boundary。
- Prompt 会要求输出高风险对齐包，并明确禁止修改业务代码。

Bugfix 拦截：

- 非 legacy Bugfix 必须填写 `下一步决策`；脚本按 `STAY / ADVANCE / RETURN / STOP / COMPLETE / ESCALATE` 自动选择阶段。尚无该章节的旧任务卡自动按 legacy 兼容，不会因本轮改造突然启用强校验。
- 非法 action、非法目标阶段、动作方向不合法或当前阶段与 `status` 不一致时，脚本留在当前阶段并输出 `decision gate` 错误。
- `ADVANCE -> coding` 缺实际现象、触发条件、预期行为、根因结论、根因证据、最小修改范围或验证计划时，不生成 Coding Prompt。
- Self Test 失败必须填写与路由一致的 `IMPLEMENTATION_ERROR / ROOT_CAUSE_ERROR / REQUIREMENT_ERROR / ENVIRONMENT_BLOCKED` 分类。
- `STOP -> human` 缺阻塞原因、已完成内容、缺少资源、人工动作或恢复阶段时，不停止到不透明的 `blocked` 状态，而是留在当前阶段补齐。
- 显式传入的 stage 如果与有效决策不一致，脚本仍按决策目标路由，并在警告区说明冲突。

动态路由回归测试：

```bash
bash ai/tool/test_ai_loop_next.sh
```

测试覆盖明确根因推进、根因被推翻、STOP、实现 / 需求错误回退、证据 Gate、L1 快速路径、Bugfix 与 Feature 自动升级、ESCALATE、L3 Memory / Change Impact / Architecture Gate、L3 历史回归和无命中 Memory 检索，共 14 个风险自适应场景。

风险自适应：

- `micro_change / light_feature` 映射 L1，`standard_delivery` 映射 L2，`high_risk_delivery` 映射 L3。
- 脚本读取 `交付风险信号`，核心风险命中但等级不足时阻止 Coding。
- `ESCALATE` 必须更新任务卡等级并记录升级前后等级和触发信号；不允许自动降级。
- L3 进入 Coding 前必须完成定向缺陷 Memory 检索和 Change Impact Analysis。
- L3 Self Test 根据风险信号检查历史缺陷、接口异常和状态恢复证据。
- Device Gate 只在 device 任务或确实需要真实设备 / 生产环境时强制，不再让所有 L3 无差别承担设备门禁。

缺陷 Memory 定向检索：

```bash
./ai/tool/ai_defect_memory_search.sh auth session login
```

命令只返回最多 5 个匹配文件，不输出或加载全部缺陷卡。

Commit 阶段：

- `commit` 只是兼容别名，会归一化为 `commit_ready`。
- `commit_ready` 只生成 Commit Agent Prompt。
- Commit Agent 只输出可复制提交信息，等待人工手动提交。
- 如果用户明确不提交 / 不需要 commit message，Review 通过后应进入 `done`，不要进入 `commit_ready`，也不要追问 JIRA ID。

Done 阶段：

- `done` 表示本轮 AI Loop 已完成到用户要求的终点。
- `done` 不代表工作区已提交，也不自动暂存、提交或推送。
- 输出 `done` 时必须说明完成依据、提交处理、工作区状态，以及后续如果需要提交应进入 Commit Agent。

## 6. ai_agent.sh

用途：把指定 Agent、Project Adapter、Role 和 Task 组合成可复制上下文，交给 Codex 使用。

```bash
./ai/tool/ai_agent.sh \
  [--project-root <path>] \
  [--adapter <id>] \
  [--role <id>] \
  [--context-mode <minimal|full>] \
  <router|requirement|bugfix|architecture|coding|selftest|review|i18n|commit> \
  <task-file>
```

旧的两个位置参数保持兼容。可移植调用应显式提供项目根目录、Adapter 和 Role。
项目根目录唯一匹配 `project-profile.yaml` 声明的标记时，Adapter 可以省略；
匹配不唯一或没有匹配时必须显式提供。

## 6.1 开发人员首批试用检查

只读检查当前项目的 Core、Project Adapter、Developer Role、分发边界，并可选
装配一个真实任务的 Router：

```bash
./ai/tool/ai_developer_pilot_check.sh \
  --project-root /path/to/project \
  [--adapter <adapter>] \
  [--task /path/to/task.md]
```

首批试用范围、任务选择和反馈要求见 `pilot/developer/README.md`。

Agent key 对应文件：

| key | 文件 |
|---|---|
| `router` | `ai/core/agents/00_router_agent.md` + Project Adapter + Role |
| `requirement` | `core.agent.requirement_breakdown` |
| `bugfix` | `core.agent.bugfix` |
| `architecture` | `core.agent.architecture_boundary` |
| `coding` | `core.agent.coding` |
| `selftest` | `core.agent.self_test` |
| `review` | `core.agent.pr_review` |
| `i18n` | `core.agent.i18n_text_ui_risk` |
| `commit` | `core.agent.commit` |

示例：

```bash
./ai/tool/ai_agent.sh router <runtime-task>
./ai/tool/ai_agent.sh --project-root /path/to/project --adapter <adapter> --role <role> router <runtime-task>
./ai/tool/ai_agent.sh --project-root /path/to/project --adapter <adapter> --role <role> --context-mode full router <runtime-task>
./ai/tool/ai_agent.sh coding /absolute/path/to/task.md
```

Router 默认使用 `minimal`：内嵌 Core Router、最小项目索引和 Task，并列出其他已解析输入路径。需要生成离线完整上下文时使用 `--context-mode full`。

完整 Router 输出包含：

```text
===== AGENT =====
<Core Router>

===== adapter.* =====
<项目配置与项目上下文>

===== role.profile =====
<Role 配置>

===== TASK =====
<Task 内容>
```

其他 Agent 在各自迁移完成前仍使用 legacy Agent 文件。

## 7. ai_task_new.sh

用途：旧任务创建脚本。当前保留为兼容入口，日常优先使用 `ai_loop_new.sh`。

```bash
./ai/tool/ai_task_new.sh <feature|bugfix|techdebt>
```

兼容别名：

| 输入 | 归一化结果 |
|---|---|
| `feat` | `feature` |
| `task` | `techdebt` |

注意：

- 该脚本生成 `legacy: true` 任务载体。
- 不支持 `device` 类型。
- 不支持新的 delivery_level 初始化能力。
- 新任务应优先使用 `ai_loop_new.sh`。

## 8. 把 Prompt 交给 Codex

推荐流程：

```bash
./ai/tool/ai_loop_status.sh <task-file>
./ai/tool/ai_loop_next.sh <task-file> <stage>
./ai/tool/ai_agent.sh <agent-key> <task-file>
```

然后把以下内容一起提供给当前 AI 客户端：

1. 根目录 `AGENTS.md` 的约束。
2. `ai_loop_next.sh` 生成的当前阶段 Prompt。
3. `ai_agent.sh` 输出的 Agent 定义和 Task 内容。
4. 必要时补充 Loader 解析出的 Core 或 Project Adapter Workflow。

不要只把聊天上下文当作任务事实。新会话恢复时，优先读取任务载体中的 `Current Checkpoint`、`Evidence`、`Next Action`。

如果 `Next Action` 指向的阶段不需要人工确认、人工验证或权限门禁，Codex 应在同一轮继续执行该阶段，并在收尾说明实际推进到了哪里。只有命中 `ALIGNMENT_PENDING`、Self Test 人工回填、环境阻塞或 Commit / Push 权限门禁时，才停下来等待 Owner。

## 9. ai_setup_check.sh

用途：只读检查当前 AI 工作流基础设施是否齐全。

```bash
./ai/tool/ai_setup_check.sh --project-root /path/to/project --adapter <adapter> --role <role>
```

检查内容：

- Core / Project Adapter / Role / Runtime owner 与兼容链接。
- Project Adapter 声明的项目规则和架构路径。
- Core 污染、配置契约和 UTF-8 环境。
- Skill 源文件与核心可执行脚本。

该脚本复用 Doctor，只输出 PASS / WARN / ERROR，不修改文件。

## 10. 常见错误

| 错误 | 处理方式 |
|---|---|
| `Task file not found` | 检查路径是否存在；可传绝对路径、workflow root 相对路径或 `runtime.tasks` 下的文件名 |
| `Unknown type` | 使用 `bugfix`、`feature`、`techdebt`、`device` 或脚本支持的别名 |
| `Unknown agent` | 使用 `router`、`requirement`、`bugfix`、`architecture`、`coding`、`selftest`、`review`、`i18n`、`commit` |
| high risk 请求 implement 被拦截 | 先进入 `alignment_pending`，输出对齐包，等待用户明确确认并回填 alignment 字段 |
| Self Test 没有真实证据 | 不能输出 `READY_FOR_QA`；记录 `NOT_RUN`、`BLOCKED` 或 `READY_FOR_QA_WITH_RISK` 的真实原因 |
| Commit 阶段想自动提交 | 不允许；只生成提交信息，人工决定是否 `git add` / `git commit` / `git push` |
| `$to-task-cards` 拆出的切片命中设备 / OTA / BLE / MQTT | 标记为 `high_risk_delivery`，进入 `ALIGNMENT_PENDING` 后再实现 |

## 11. 脚本真实性

本手册按当前实际存在脚本编写：

```text
ai/tool/install_ai_agent.sh
ai/tool/install_skills.sh
ai/tool/ai_loop_new.sh
ai/tool/ai_loop_status.sh
ai/tool/ai_loop_next.sh
ai/tool/ai_agent.sh
ai/tool/ai_task_new.sh
ai/tool/ai_setup_check.sh
ai/tool/ai_core_loader.sh
ai/tool/ai_core_doctor.sh
ai/tool/ai_core_compat_check.sh
ai/tool/test_ai_core_doctor.sh
ai/tool/test_ai_core_compat.sh
ai/tool/test_ai_router_loader.sh
ai/tool/ai_distribution_check.sh
ai/tool/ai_distribution_package.sh
ai/tool/ai_developer_pilot_check.sh
ai/tool/test_ai_distribution_package.sh
ai/tool/test_ai_install.sh
```

如果未来新增、删除或改名脚本，先以脚本自身 `usage()` 和实际行为为准，再同步更新本手册。
