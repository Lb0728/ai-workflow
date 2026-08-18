# AI Workflow 术语表 / Glossary

本表统一中英文术语，所有文档（README、任务卡、Contract、Agent、Workflow）引用同一含义，
避免"同一个概念两种写法"造成的漂移。新增文档前先查本表。

## 核心概念

| 中文 | English | 含义 |
|---|---|---|
| 任务载体 | task carrier | 承载任务事实的文档：PRD / Fast Brief / Task Card / Micro Change / Execute Request |
| 交付等级 | delivery_level | `micro_change` / `light_feature` / `standard_delivery` / `high_risk_delivery` |
| 风险强度 | risk tier | L1 = micro_change/light_feature，L2 = standard_delivery，L3 = high_risk_delivery |
| 门禁 | Gate | L0/L1/L2/L3 校验；结果只能是 PASS / FAIL / NOT_RUN / N/A / BLOCKED |
| 提测结论 | QA conclusion | READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA / BLOCKED |
| 高风险对齐 | high-risk alignment | 高风险任务进入 IMPLEMENT 前必须 `alignment_status: confirmed` |
| 阶段 | stage | analyze / impact_map / architecture / capability / alignment_pending / implement / ready_for_self_test / validation_pending / self_test_in_progress / review / commit_ready / ready_for_qa / done / blocked |
| 决策动作 | decision action | STAY / ADVANCE / RETURN / ESCALATE / STOP / COMPLETE |
| 循环收口 | Loop Closeout | 阶段末尾统一收口块：当前状态 / 是否 Done / 唯一下一步 / 是否需要 Owner 输入 |
| 真源 | source of truth | 某类事实的唯一权威来源（如 project.rules、UserProfileStore.profile） |
| 证据优先 | Evidence First | 关键决策先以任务直接资料和真实实现为准，再使用通用原则 |
| 不可变约束 | immutable constraint | 任何层不可覆盖的约束：Core Guardrail、Company Policy、禁自动 Commit/Push、硬 Gate、STOP |

## 架构层

| 中文 | English | 含义 |
|---|---|---|
| 核心 | Core | 状态协议、风险等级、Gate 词汇、通用 Agent/Workflow/Skill/Template 的唯一真源 |
| 宿主适配器 | Host Adapter | hosts/<host>/host.yaml：指令入口、Skill 位置、权限模型、状态呈现；不选模型 |
| 项目适配器 | Project Adapter | adapters/<id>/：project-profile.yaml + config/ + context/，注入项目事实 |
| 公司策略 | Company Policy | policies/company/：Commit/Review/Security/Delivery 公司级约束 |
| 角色 | Role | roles/<role>/role-profile.yaml：阶段、权限、执行策略 |
| 运行时 | Runtime | 安装后 `<project>/.ai-runtime/`；源码回退 `runtime/`；任务实例唯一真源 |
| 加载器 | Loader | core/loader/ai_workflow_loader_v2.sh：describe / validate / resolve |
| 路由器 | Router | core/router/ai_loop_next_v2.sh：解析下一状态 / Gate / Agent |
| 发现 | Discovery | discovery/：项目栈检测、project-profile 生成、schema 校验 |
| 分发包 | distribution package | dist/package.sh 从干净 commit 生成的版本化归档 |

## 组件与文件

| 中文 | English | 含义 |
|---|---|---|
| 任务卡 | Task Card | core/templates/task_card_template.md |
| 快速简报 | Fast Brief | core/templates/fast_brief_template.md |
| 微变更 | Micro Change | core/templates/micro_change_template.md |
| 高风险对齐模板 | High Risk Alignment template | core/templates/high_risk_alignment_template.md |
| 自测报告 | Self Test Report | core/templates/self_test_report_template.md |
| 缺陷记忆 | Defect Memory | defect_memory/：最小缺陷卡，L1 不检索 / L2 线索检索 / L3 定向检索（≤5 张） |
| 交接快照 | Handoff | handoffs/：跨会话短恢复状态，引用文件路径而非复制全文 |

## 状态机（stage → decision stage 映射）

| Loop stage | Decision stage | 说明 |
|---|---|---|
| requirement_breakdown | requirement_breakdown | 需求拆解 |
| analyze / impact_map / fix_ready | bugfix_diagnosis | Bug 诊断 |
| architecture / capability / alignment_pending | arch_boundary | 架构边界 |
| implement / ready_for_self_test | coding | 编码 |
| validation_pending / self_test_in_progress / ready_for_qa | self_test | 自测 |
| review / i18n / commit_ready | pr_review | 审查 |
| blocked | human | 人工阻塞 |
| done | loop_closeout | 收口 |
