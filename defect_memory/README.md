# Defect Memory

本目录只沉淀已经有真实证据的线上逃逸或重复缺陷，不保存聊天推测，也不代替 Task Card。

## 使用规则

- 每张卡只记录最小可复用事实：feature、symptom、root cause、architecture risk、regression scenarios、change triggers 和证据来源。
- 当前任务只用 feature、module、state、API 等直接关键词检索相关卡；不把整个目录加载进上下文。
- 没有命中时在任务卡写明“未找到相关历史缺陷记录”，不得编造历史。
- 命中后只读取匹配卡，并把必须回归的场景写入当前 Task Card。
- L1 默认不检索；L2 仅在已有同类问题线索时检索；L3 必须执行一次定向检索。

检索命令：

```bash
./ai/tool/ai_defect_memory_search.sh auth session login
```

新卡从 [template.md](template.md) 复制，文件名建议使用 `<feature>-<short-symptom>.md`。
