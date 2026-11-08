因此，前端已经具备日程管理能力，但 Agent 交互层还要补。
目标架构
建议最终形成下面这条链路：
HarmonyOS Agent 对话页
        │
        ▼
POST /agent/invoke
        │
        ▼
LangGraph 日程 Agent
  ├─ 意图识别
  ├─ 参数抽取
  ├─ 确定性查询候选日程
  ├─ 参数校验
  ├─ 缺失信息澄清
  ├─ 危险操作确认
  └─ Tool Calling
        │
        ├─ create_schedule
        ├─ query_schedules
        ├─ update_schedule
        └─ delete_schedule
        │
        ▼
日程数据库
LangChain 当前适合快速创建基础 Agent；更复杂的状态、持久化、人工确认和可恢复执行，可以直接使用 LangGraph。LangChain 的 Agent 本身也建立在 LangGraph 能力之上。LangChain 官方教程也将简单 Agent 与需要精细控制的自定义 LangGraph 工作流区分开来。
完整 Todo List
阶段一：整理现有工程
- [ ] 删除客户端直接访问 DeepSeek 的逻辑。
- [ ] 删除客户端中的 DEEPSEEK_API_URL 和 API Key 字段。
- [ ] 所有模型调用统一放到 Flask 后端。
- [ ] 统一配置方式，使用环境变量读取 DEEPSEEK_API_KEY。
- [ ] 清理仓库中的 __pycache__、`.pyc`、Session 文件和测试用户数据。
- [ ] 完善 .gitignore。
- [ ] 检查 Git 历史中是否曾提交真实 API Key。
- [ ] 统一前后端日程数据结构。
- [ ] 将创建、修改、删除、查询的返回格式统一为一个 Agent Response。
建议响应结构：
{
  "status": "need_confirmation",
  "message": "你要删除明天下午的项目评审会议吗？",
  "action": {
    "type": "delete_schedule",
    "arguments": {
      "schedule_id": 12
    }
  },
  "conversation_id": "xxx"
}
完成标准：客户端不再直接接触模型密钥，所有 AI 请求只走后端。
阶段二：建立 LangChain 基础 Agent
2.1 接入模型
- [ ] 安装 langchain、对应模型 Provider 包和 pydantic。
- [ ] 使用统一的模型初始化模块。
- [ ] 配置温度、超时、最大重试次数。
- [ ] 将模型名称、Base URL 等放入环境配置。
- [ ] 增加 Mock Model，供测试环境使用。
不要把 OpenAI 兼容接口调用散落在多个文件中，建议集中成：
backends/agent/
├── model.py
├── prompts.py
├── schemas.py
├── tools.py
├── graph.py
└── service.py
2.2 定义 Agent Tools
- [ ] 实现 create_schedule。
- [ ] 实现 query_schedules。
- [ ] 实现 update_schedule。
- [ ] 实现 delete_schedule。
- [ ] 可选实现 check_schedule_conflict。
- [ ] 可选实现 get_current_datetime。
每个 Tool 必须具备：
- 明确的功能描述；
- Pydantic 参数模型；
- 用户权限校验；
- 确定性业务逻辑；
- 统一错误结构；
- 操作日志；
- 可独立单元测试。
例如：
class CreateScheduleInput(BaseModel):
    title: str
    start_time: datetime
    end_time: datetime | None = None
    location: str | None = None
    repeat_rule: str | None = None
- [ ] 工具内校验开始时间和结束时间。
- [ ] 工具内校验周期规则。
- [ ] 更新、删除前验证日程是否属于当前用户。
- [ ] 禁止模型直接生成 SQL 或访问底层文件。
- [ ] 工具返回机器可读结果，而不是随意拼接文本。
完成标准：模型只决定调用什么工具，真正的数据操作全部由受控 Tool 完成。
阶段三：结构化输出与业务校验
- [ ] 定义意图枚举：`CREATE`、`QUERY`、`UPDATE`、`DELETE`、`GENERAL`。
- [ ] 定义 Agent Action Schema。
- [ ] 定义工具参数 Schema。
- [ ] 校验时间格式。
- [ ] 校验结束时间晚于开始时间。
- [ ] 校验修改和删除目标确实存在。
- [ ] 校验周期规则合法。
- [ ] 校验模型返回的 ID 属于候选日程。
- [ ] 对非法输出进行有限次数重试。
- [ ] 重试失败后降级为人工填写。
不能再只依赖：
json.loads(model_output)
理想状态是：
模型结构化输出
  → Pydantic 校验
  → 业务规则校验
  → 用户确认
  → Tool 执行
完成标准：模型产生错误 JSON 或非法时间时，不会污染业务数据。
阶段四：用 LangGraph 编排完整工作流
这是项目从“LangChain 工具调用 Demo”升级为“完整 Agent”的关键。
- [ ] 定义统一的 AgentState。
- [ ] 建立意图识别节点。
- [ ] 建立参数抽取节点。
- [ ] 建立候选日程查询节点。
- [ ] 建立参数校验节点。
- [ ] 建立信息澄清节点。
- [ ] 建立操作确认节点。
- [ ] 建立 Tool 执行节点。
- [ ] 建立结果生成节点。
- [ ] 建立异常处理与降级节点。
- [ ] 配置节点重试策略。
- [ ] 配置 Checkpointer 保存执行状态。
- [ ] 每次请求使用稳定的 thread_id。
建议状态结构：
class AgentState(TypedDict):
    messages: list
    user_id: str
    conversation_id: str
    intent: str | None
    tool_name: str | None
    tool_args: dict | None
    candidates: list
    missing_fields: list[str]
    confirmation_required: bool
    confirmed: bool
    tool_result: dict | None
    error: str | None
推荐状态流：
START
  → classify_intent
  → extract_parameters
  → validate
      ├─ 信息不足 → clarify → 等待用户 → validate
      ├─ 危险操作 → confirm → 等待用户
      ├─ 参数合法 → execute_tool
      └─ 无法处理 → fallback
  → generate_response
  → END
对于需要用户确认的操作，可以使用 LangGraph 的 interrupt() 暂停执行，并借助 Checkpointer 保存状态，用户确认后从原位置恢复。LangGraph 官方说明也将人工确认、持久化、重试和可恢复执行作为典型工作流。

完成标准：一次 Agent 执行可以暂停等待用户，后续请求能从原状态继续，而不是重新让模型猜测上下文。
阶段五：实现多轮澄清
- [ ] 识别缺失的标题、日期、时间等参数。
- [ ] 一次只追问必要信息。
- [ ] 将用户补充内容合并到当前 Agent State。
- [ ] 支持“明天下午提醒我开会”这类不完整输入。
- [ ] 支持“改到四点”这种依赖上文的表达。
- [ ] 支持“删除刚才创建的那个”。
- [ ] 支持多个候选日程时让用户选择。
- [ ] 用户取消后终止当前操作。
- [ ] 会话超时后清理未完成状态。
示例：
用户：明天下午提醒我交作业
Agent：你希望几点提醒？
用户：三点
Agent：将于明天下午 3:00 创建“交作业”提醒，确认吗？
用户：确认
Agent：已创建。
完成标准：Agent 不会通过臆测补齐关键参数。
阶段六：增加 Human-in-the-loop
操作分级建议：
操作	是否确认
查询日程	不需要
创建日程	建议预览确认
修改日程	必须确认变更前后
删除日程	必须确认
批量修改/删除	二次确认


- [ ] 创建操作返回预览卡片。
- [ ] 修改操作展示变更前后 Diff。
- [ ] 删除操作展示目标日程详情。
- [ ] 批量操作展示影响数量。
- [ ] 用户可以确认、拒绝或编辑参数。
- [ ] 后端不能仅依赖前端按钮保护危险操作。
- [ ] 确认请求应带短期有效的操作 ID。
- [ ] 防止同一个确认操作重复执行。
完成标准：模型不能未经用户确认直接执行破坏性操作。
阶段七：补 Agent 前端页面
目前已有日程表单页，但缺少完整的 Agent UI。
必需页面和组件
- [ ] 新增 AgentChatPage.ets。
- [ ] 增加用户消息气泡。
- [ ] 增加 Agent 回复气泡。
- [ ] 增加流式生成状态。
- [ ] 增加“正在识别意图”“正在查询日程”等状态提示。
- [ ] 增加日程预览卡片。
- [ ] 增加确认/取消按钮。
- [ ] 增加参数补充表单。
- [ ] 增加候选日程选择卡片。
- [ ] 增加工具执行成功/失败状态。
- [ ] 增加重新尝试按钮。
- [ ] 增加会话历史列表。
- [ ] App 重启后恢复未完成会话。
前端接口
- [ ] POST /agent/invoke：发起或继续对话。
- [ ] POST /agent/confirm：确认操作。
- [ ] POST /agent/reject：拒绝操作。
- [ ] GET /agent/thread/:id：恢复会话。
- [ ] 可选 SSE 接口：流式返回 Agent 状态和文本。
完成标准：用户可以完全通过对话完成创建、查询、修改和删除，而不是只能回填创建表单。
阶段八：上下文和记忆
- [ ] 使用 user_id + thread_id 隔离会话。
- [ ] 将对话状态持久化。
- [ ] 设置会话过期时间。
- [ ] 限制最大历史消息数。
- [ ] 对旧消息进行摘要。
- [ ] 不把所有历史日程都塞进 Prompt。
- [ ] 只向模型提供当前任务所需的候选数据。
- [ ] 对敏感信息进行脱敏。
- [ ] 提供删除会话历史的能力。
注意区分：
- 短期记忆：当前对话里“改到四点”指什么；
- 业务数据：数据库中的日程；
- 长期偏好：例如默认提前 30 分钟提醒。
不要把数据库当作 LangChain Message History，也不要把 Message History 当作数据库。
阶段九：可观测性
- [ ] 记录每次模型调用的耗时。
- [ ] 记录 Token 使用量和估算成本。
- [ ] 记录意图分类结果。
- [ ] 记录工具调用名称和参数摘要。
- [ ] 记录澄清次数。
- [ ] 记录操作是否被用户确认。
- [ ] 记录工具执行成功率。
- [ ] 记录结构化输出失败率。
- [ ] 记录模型重试次数。
- [ ] 使用 request_id 串联前端、Agent 和 Tool 日志。
- [ ] 可选接入 LangSmith Tracing。
LangSmith 可用于离线评测、回归测试和线上质量监控；官方文档将这些分别归类为 benchmarking、unit tests、regression tests 和 online evaluation。LangSmith 评测类型

完成标准：遇到一次错误操作时，可以还原模型看到的上下文、选择的工具、参数以及失败节点。
阶段十：建立评测集
这是面试价值最高、也最容易被忽略的部分。
数据集
- [ ] 创建至少 50 条基础评测数据。
- [ ] 最好扩展到 100～200 条。
- [ ] 为每条样例标注意图。
- [ ] 标注预期 Tool。
- [ ] 标注预期 Tool 参数。
- [ ] 标注是否应该澄清。
- [ ] 标注是否需要确认。
- [ ] 标注是否应该拒绝执行。
场景覆盖
- [ ] 一次性日程；
- [ ] 相对日期；
- [ ] 跨周、跨月、跨年；
- [ ] 周期性日程；
- [ ] 修改；
- [ ] 删除；
- [ ] 查询；
- [ ] 多候选项；
- [ ] 缺失时间；
- [ ] 无效日期；
- [ ] 上下文指代；
- [ ] Prompt 注入；
- [ ] 越权访问其他用户日程；
- [ ] 重复提交；
- [ ] 非日程闲聊。
指标
- [ ] 意图分类准确率；
- [ ] Tool 选择准确率；
- [ ] 参数完全匹配率；
- [ ] 澄清触发准确率；
- [ ] 危险操作误执行率；
- [ ] 端到端任务成功率；
- [ ] 平均响应时间；
- [ ] 单任务平均 Token 成本。
完成标准建议：
意图准确率 ≥ 95%
Tool 选择准确率 ≥ 95%
关键参数准确率 ≥ 90%
未经确认的删除执行率 = 0
核心场景端到端成功率 ≥ 90%
阶段十一：测试与 CI
- [ ] 每个 Tool 都有单元测试。
- [ ] Schema 校验有边界测试。
- [ ] LangGraph 每条分支都有测试。
- [ ] 使用 Mock Model 测试固定 Tool Call。
- [ ] 使用少量真实模型做集成测试。
- [ ] 测试会话隔离。
- [ ] 测试重复确认的幂等性。
- [ ] 测试模型超时和限流。
- [ ] 测试数据库失败。
- [ ] 测试用户取消操作。
- [ ] 在 CI 中运行非模型依赖测试。
- [ ] 定期运行 Agent 回归评测。
阶段十二：安全和工程收尾
- [ ] API Key 仅存在后端环境变量中。
- [ ] 后端接口要求登录。
- [ ] 每个 Tool 强制校验数据归属。
- [ ] 对输入长度做限制。
- [ ] 对模型输出做 Schema 校验。
- [ ] 限制单轮最大 Tool 调用次数。
- [ ] 防止无限 Agent 循环。
- [ ] 删除操作支持软删除或撤销。
- [ ] 为写操作增加幂等键。
- [ ] 增加限流。
- [ ] 日志中不记录密码、Cookie 和完整敏感数据。
- [ ] 完善 Docker、启动脚本和 .env.example。
- [ ] README 增加架构图和演示 GIF。
- [ ] README 记录评测指标和已知限制。
RAG 是否要纳入 Todo
不放进核心 Todo。

完整的 LangChain Agent 不等于必须有 RAG。你的项目核心是：
自然语言理解 + Tool Calling + 状态管理 + 人工确认
不是知识问答。

可以将 RAG 作为可选扩展：
- [ ] 上传课程表或会议通知；
- [ ] 解析 PDF、邮件或教务文档；
- [ ] 对文档进行分块和索引；
- [ ] 检索与当前请求相关的内容；
- [ ] 从检索结果中提取日程；
- [ ] 用户确认后调用 create_schedule。
这个功能可以命名为：
从文档自动提取日程

它是合理的 RAG 场景，但不应该阻塞 Agent 主链路。
推荐开发顺序
如果目标是尽快把它升级到简历可用，我建议按这个顺序：
1. 统一客户端和后端 AI 链路；
2. 定义四个日程 Tools；
3. 使用 Pydantic 约束 Tool 参数；
4. 用 LangGraph实现解析、澄清、确认、执行；
5. 开发 Agent 对话页面；
6. 完成 50 条评测集；
7. 增加日志、测试和 README；
8. 最后再考虑文档 RAG。
完成前 6 项，项目就可以比较有底气地写成：
基于 LangChain/LangGraph 构建 AI 日程 Agent，通过结构化 Tool Calling 实现日程创建、查询、修改和删除；引入多轮参数澄清与 Human-in-the-loop 执行确认，并基于自建评测集验证意图识别、工具选择和端到端任务成功率。
