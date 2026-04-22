# Role & Context
你是一位资深的鸿蒙应用开发工程师（ArkTS + ArkUI + Stage模型）。请帮我从零构建一个名为 "SmartSchedule" 的多端日程管理应用。
我已经拥有现成的后端服务，**你不需要编写任何后端代码**。你的任务是专注于鸿蒙客户端的开发，并严格按照我提供的后端接口文档进行网络请求联调。由于我对底层 Native 开发不熟悉，请**完全使用纯 ArkTS 和 ArkUI 进行开发，绝对不要涉及 C++/NDK 或复杂的分布式流转底层代码**。

# Tech Stack Constraints
- **前端 (HarmonyOS Next):** 使用 API 9 或以上版本，基于 Stage 模型开发，UI 层使用 ArkTS 声明式语法。
- **架构模式:** 严格遵循 MVVM 架构，将 UI、状态管理、网络请求彻底解耦。

# Backend API Documentation (严格以此为准)
后端本地调试 Base URL: `http://127.0.0.1:5000/`
（注：鸿蒙模拟器/真机访问本地后端时，可能需要将 IP 替换为宿主机局域网 IP）

## 1. Auth Routes (/auth)
- `POST /auth/register`: 传入 `{"username": "user", "password": 123}`。返回 `{"success": true/false, "error": "..."}`。
- `POST /auth/login`: 传入同上。成功返回 `{"success": true}`。**重要提示：成功登录后，后端会在 Cookie 中隐式返回 `user_id`。后续所有接口请求都必须携带此 Cookie，否则会报错。**

## 2. Schedule Routes (/schedule)
返回值结构约定：`schedules: []`, `schedule: {}`, `ids: []`, `success: bool`, `error: str`。
- `GET /schedule`: 获取所有未归档日程。
- `POST /schedule`: 创建日程。传入 `{"schedules": [...]}`。返回 `{"ids": [...]}`。日程对象需包含 `id` (新建传-1), `timestamp`, `type`, 以及 `content` (包含 title, begin_time, end_time, location, repeat 等字段)。
- `GET /schedule/<int:id>`: 获取单个日程详情。
- `PUT /schedule/<int:id>`: 传入 `{"schedule": {}}` 全量更新覆盖。
- `DELETE /schedule/<int:id>`: 删除日程。
- `GET /schedule/archive/<int:id>`: 归档日程（标记完成）。
- `GET /schedule/remind_start` / `GET /schedule/remind_before`: 获取提醒。
- `GET /schedule/sync`: 传入 `{"schedules": []}` 进行端云数据全量同步覆盖。
- `GET /schedule/quantity` (或 带 /<int:days>): 获取未归档日程数量。

# Core Requirements
1. **用户与个性化:** 接入 `/auth/login` 和 `/auth/register`，并在客户端妥善持久化保存 Cookie（如使用 `@ohos.data.preferences`），确保应用杀后台重启后仍保持登录状态。支持头像和签名的本地 UI 设置。
2. **AI 语义解析 (核心亮点):** 提供文本输入框，用户输入自然语言。客户端需封装一个通用的 AI 请求服务（你可以先 mock 接口或使用标准 HTTP 请求调用外部 LLM API），将解析出的 JSON 结果直接映射为 `POST /schedule` 所需的 payload 格式并提交给我的后端。
3. **常规任务管理:** 结合 `/schedule` 下的 GET/POST/PUT/DELETE 接口，实现完整的增删改查。使用 `GET /schedule/archive/<id>` 实现任务打勾完成的逻辑。
4. **状态面板:** 展示未完成任务数量（通过 `/schedule/quantity`），支持列表和日历两种视图切换。
5. **动态图标机制:** 根据 `/schedule/quantity` 返回的未完成数量阈值，调用鸿蒙系统接口动态替换桌面应用图标。
6. **多端部署与响应式:** 界面需自适应手机、平板和智能手表。利用 `GridRow/GridCol` 实现：平板上双栏显示，手机和手表单栏显示。

# Execution Steps
请分阶段与我确认，不要一次性输出所有代码：
- **阶段 1: 基础设施与网络层搭建。** 生成前端 Stage 模型的基础目录结构。封装通用的 `HttpUtil`，**必须实现统一的拦截器逻辑来处理登录后的 Cookie 存储和自动携带**。完成后停顿。
- **阶段 2: 鉴权与用户 UI。** 实现登录、注册页面，联调 `/auth` 接口，确保 Cookie 机制运转正常。完成后停顿。
- **阶段 3: 核心业务联调。** 实现日程的日历/列表 UI，并对接 `/schedule` 的全套 CRUD 接口。完成后停顿。
- **阶段 4: 进阶功能实现。** 完成 AI 文本解析转 Schedule Payload 的逻辑，完善多端响应式布局，接入动态图标 API。

请问是否理解？如果理解，请直接开始【阶段 1】的代码输出。