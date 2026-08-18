---
name: ai-workflow
description: 用 AI Workflow 状态机驱动编码任务（建卡、看合法下一步、按 Agent 执行、写回证据、finish 收口）。仅当用户要求按 AI Workflow 流程执行任务、或任务卡需要推进时使用；通过 bash 调用 ai-workflow CLI，不手工猜状态。
---

# AI Workflow Loop Driver

把 DeepSeek Harness 当作 AI Workflow 的一个 Host：任务以任务卡（Task Card /
Fast Brief / Micro Change）为真源，状态推进全部由 `ai-workflow` CLI 校验，
你负责执行每个阶段的 Agent 工作并把证据写回任务卡。

## 前置

- `ai-workflow` CLI 已安装（`ai-workflow doctor` 能通过）。
- 当前项目已初始化（项目根目录存在 `.ai/` 或等价安装）。
- 未安装时：先让用户安装并初始化，不跳过流程硬编状态。

## 循环步骤

1. **定位任务卡**：`.ai/runtime/tasks/` 下按 task_id 查找；找不到就问用户。
2. **看合法下一步**：`ai-workflow next <task-file>`。只执行输出的
   "本次选择阶段"（阶段 / Agent / 模式），不手工猜阶段。
3. **执行 Agent 工作**：按 Router 输出的 Agent 定义干活（需求拆解、Bug 诊断、
   编码、自测、Review…），遵守任务卡的验收标准与"不做范围"。
4. **写回证据**：把真实结果写进任务卡的对应章节（证据记录、门禁结果、
   Implement Summary、Self Test 红绿灯…）。禁止编造证据；`NOT_RUN` 不算 PASS。
5. **收口推进**：写 `## Loop Closeout`（当前状态 / 是否 Done / 唯一下一步 /
   是否需要 Owner 输入），然后 `ai-workflow finish <task-file>` 校验并推进。
6. **循环**：回到第 2 步，直到 `done` 或命中硬检查点。

## 硬检查点（必须停下等用户）

- `high_risk_delivery` 进入 IMPLEMENT 前：输出对齐包，等用户明确确认
  （"按方案实施"等），再把 `alignment_status` 改为 confirmed。
- Self Test 需要真机 / 设备 / 账号 / 人工验证：输出最小人工验证清单并等待回填。
- Review 通过且需要提交：`COMMIT_READY` 由 Commit Agent 生成提交信息，
  **你自己不执行 git add / commit / push**，等用户手动提交。
- Router 输出 `blocked`：把阻塞项收敛成一个最小问题问用户。

## 禁止

- 不手工改任务卡 `status` 字段绕过 Router / finish 校验；
- 不把聊天猜测写成任务卡事实；
- 不跳过失败或缺失的 Gate；
- 不执行任务卡之外的无关改动。
