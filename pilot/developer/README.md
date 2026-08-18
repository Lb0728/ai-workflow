# 开发人员首批试用

## 目标

第一批只让开发人员使用统一版本化安装包处理真实、低风险、边界清楚的任务：

```text
Core
+ demo-project Project Adapter（示例，可按需扩展为自己的项目 Adapter）
+ Developer Role
+ Codex / Cursor / Claude Code Client Integrations
+ empty Runtime
```

用于验证：

1. 同一份包能否在不同开发者电脑和不同项目路径安装；
2. Project Adapter 是否根据当前项目自动识别；
3. Router 是否读取真实项目事实，而不是脱离代码推演；
4. L1 任务成本是否合理；
5. Gate、Self Test 和 Review 是否给出可执行下一步；
6. 包内是否不携带创建者路径、Git 历史或其他人的 Runtime。

本阶段不创建 QA Role，不要求测试同事使用，也不从高风险设备、协议、迁移或
生产环境任务开始。

## Owner 生成统一试用包

只从已经提交且工作区干净的版本生成：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./tool/ai_distribution_package.sh \
    --project-root /path/to/validation-project \
    --distribution example \
    --role developer \
    --output-dir /path/to/output
```

将同一份 `.tar.gz` 和 `.sha256` 交给所有参与者。不要按人员重新生成，也不要直接
分享完整私有仓库。

发布前同时验证两个真实项目：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./tool/test_ai_distribution_package.sh \
    examples/demo-project
```

## 开发人员安装

先验证校验值并解压：

```bash
shasum -a 256 -c <package>.tar.gz.sha256
tar -xzf <package>.tar.gz
```

进入自己的项目根目录，选择自己实际使用的客户端：

```bash
cd /your/path/to/project

bash /path/to/extracted-package/tool/install_ai_agent.sh --client codex
# 或
bash /path/to/extracted-package/tool/install_ai_agent.sh --client cursor
# 或
bash /path/to/extracted-package/tool/install_ai_agent.sh --client claude-code
```

安装器使用当前目录作为 `project_root`，自动识别当前项目的 Project Adapter，创建本地 `ai` 入口和独立的 `.ai-runtime/`，安装同一份 Skills，
并运行 Setup Check。创建者电脑的绝对路径不会进入安装过程；不同项目的任务卡、
handoff 和证据也不会混在一起。

解压后的包目录是本地 `ai` 和 Skill 链接的来源，需要放在稳定位置。移动或删除后，
在新位置重新运行安装器即可修复链接；升级包时也应从新版本目录重新运行安装器。

有些项目不会从 Git checkout 获得 `AGENTS.md`。安装器在该文件缺失且
Adapter 自带默认项目规则时链接默认规则；如果开发者已经有自己的 `AGENTS.md`，
安装器不会覆盖。

安装后重新打开客户端会话。Skill 调用形式：

- Codex：`$grill-me`、`$to-prd` 等；
- Cursor：`/grill-me`、`/to-prd` 等；
- Claude Code：`/grill-me`、`/to-prd` 等。

## 开始前检查

在自己的项目根目录运行：

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./ai/tool/ai_developer_pilot_check.sh \
    --project-root "$PWD"
```

预期结果为 `RESULT PASS errors=0`，并且输出的 Adapter 与当前项目一致。识别
错误、项目资料缺失、校验值失败或分发边界失败时，不开始真实任务。

## 第一个试用任务

选择一个真实 L1 任务：

- 目标、范围、关键规则和验收方向已经明确；
- 单文件或少量直接依赖；
- 不修改共享状态、接口契约、存储或跨仓库能力；
- 不依赖真实设备或生产环境；
- 可以完成至少一项自动检查和一个主要相邻场景验证。

创建自己的任务载体：

```bash
./ai/tool/ai_loop_new.sh feature <TASK-ID> <slug> P2 light_feature
```

填写后检查 Router 装配：

```bash
./ai/tool/ai_developer_pilot_check.sh \
  --project-root "$PWD" \
  --task /path/to/your-task.md
```

然后按 `ai_loop_status.sh` / `ai_loop_next.sh` 的合法下一步推进。不要把他人的
任务卡复制成自己的证据，也不要把 `NOT_RUN` 回填成 `PASS`。

## 本轮验证完成条件

每位参与者至少提交一份 `feedback-template.md`，并且试用任务能够证明：

- Adapter 识别和 Router 装配正确；
- 使用的是当前项目规则、源码或任务资料；
- 没有凭空新增 owner、bridge、callback、接口或阻塞条件；
- L1 任务没有被无依据升级成重流程；
- 实现完成后仍进入 Self Test 和 Review，而不是直接宣称可提测；
- 未执行项和人工验证项被真实记录。

试用任务是否提交代码，仍遵守项目仓库的正常人工确认和提交规则。

## 立即停止并反馈

出现以下任一情况时停止当前 AI Loop：

- 自动选择了错误的 Project Adapter；
- Router 未加载当前项目事实，或混入另一个 Project Adapter 的事实；
- AI 把未读取资料写成确定事实；
- 高风险任务绕过 `ALIGNMENT_PENDING`；
- `NOT_RUN` 被当成 `PASS`；
- 分发包包含其他开发人员的任务历史、日志、个人路径或凭证内容；
- 分发包校验值失败，或 `PACKAGE_METADATA.txt` 版本与通知不一致。

保留命令、任务载体和最小错误输出，按反馈模板记录；不要把敏感数据粘贴到反馈中。
