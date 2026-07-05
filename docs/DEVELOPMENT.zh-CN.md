# Timer_Harmony 开发说明

[English](DEVELOPMENT.md)

本文档基于当前仓库内容整理，用于说明项目结构、运行方式、配置位置和下一步清理重点。

## 仓库范围

Timer_Harmony 包含两个主要部分：

- HarmonyOS 客户端：位于 `entry/src/main/ets/`，使用 ArkTS / ArkUI
- 后端服务：位于 `backends/`，基于 Flask，提供日程与对话相关接口

根据 `entry/src/main/module.json5`，客户端面向 phone、tablet、2in1、wearable 等 HarmonyOS 设备类型。

## 客户端模块

```text
entry/src/main/ets/
|-- common/
|   |-- HttpUtil.ets              # 后端与 AI 请求层
|   |-- PreferencesUtil.ets       # 本地偏好与会话辅助方法
|   |-- ScheduleModel.ets         # 日程数据结构
|   |-- BreakpointUtil.ets        # 响应式布局工具
|   |-- BadgeService.ets          # 角标相关服务逻辑
|   `-- DynamicIconService.ets    # 动态图标档位映射与应用内预览
|-- db/
|   |-- DbHelper.ets
|   |-- ScheduleRepository.ets
|   |-- SyncManager.ets
|   |-- DistributedSyncManager.ets
|   `-- AppStatusStore.ets
|-- pages/
|   |-- LoginPage.ets
|   |-- MainPage.ets
|   |-- CreateSchedulePage.ets
|   |-- ScheduleDetailPage.ets
|   `-- ScheduleListPage.ets
`-- entryability/
    `-- EntryAbility.ets
```

主要页面声明位于 `entry/src/main/resources/base/profile/main_pages.json`。

## 后端模块

```text
backends/
|-- app/                 # Flask 应用初始化
|-- config/              # 运行配置
|-- core/                # 日程、鉴权与 AI 相关核心逻辑
|-- routes/              # Flask 路由定义
|-- tests/               # 后端测试
|-- data/                # 本地开发数据
`-- requirements.txt
```

后端依赖包括 Flask、OpenAI 兼容客户端调用、PyYAML、Requests、Pytest、Flask-Session 和 Flask-CORS。

## 运行 HarmonyOS 客户端

1. 使用 DevEco Studio 打开仓库。
2. 同步并构建 HarmonyOS 工程。
3. 配置客户端请求层使用的后端 Base URL。
4. 在 HarmonyOS 真机或模拟器上运行应用。

真机联调后端时，不要使用 `127.0.0.1`，应改为电脑在局域网中的 IP 地址。

## 运行后端

从仓库根目录执行：

```powershell
cd backends
pip install -r requirements.txt
flask run --host=0.0.0.0
```

默认本地后端通常为：

```text
http://127.0.0.1:5000
```

如果从手机或模拟器访问，需要替换成宿主机的局域网 IP。

## 配置说明

不要提交真实 API Key 或私有服务地址。

仓库中仅保留 DeepSeek Key 的示例文件：

```text
backends/config/deepseek_api_key.example.txt
```

本地运行后端时自行创建：

```text
backends/config/deepseek_api_key.txt
```

真实 Key 文件已加入 Git 忽略列表。

## 关键流程

- 鉴权：注册、登录、本地持久化会话
- 日程 CRUD：创建、列表、详情、更新、删除
- 完成/归档：将日程标记为完成或归档
- AI 解析：将自然语言文本转换成日程 payload
- 本地持久化：基于 RDB 保存日程数据
- 同步流程：跟踪待创建、待更新、待删除状态
- 动态图标：根据待办数量映射图标档位，并提供应用内预览

## 测试

后端测试位于：

```text
backends/tests/
```

常用命令：

```powershell
cd backends
pytest -k "schedule"
pytest -k "chat"
```

AI 相关测试可能需要有效的服务商 Key 和网络访问。

## 截图清单

后续补截图时，建议优先覆盖这些页面：

- 登录/注册
- 日程首页概览
- 带自然语言输入的日程创建页
- 日程详情页
- 日程列表页
- 动态图标或应用内图标预览

推荐存放路径：

```text
docs/assets/
```

建议使用压缩后的 PNG 或 WebP，并在 `README.md` 和 `README.zh-CN.md` 中引用。

## 下一步清理项

- 从仓库中移除已跟踪的运行缓存文件，例如 `__pycache__` 和 Flask session 数据。
- 在 `docs/` 下补完整后端 API 文档。
- 发布生产版本前，将直接调用 AI 服务商的逻辑收敛到后端接口。
- 增加本地开发用的 `.env` 或配置模板。

