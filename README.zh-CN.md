# Timer_Harmony

[English](README.md) | 简体中文

Timer_Harmony 是一个基于 HarmonyOS 的智能日程管理应用，使用 ArkTS、ArkUI 和 Stage 模型开发。

项目重点是把自然语言日程意图转换成结构化任务，并围绕本地存储、后端接口和 HarmonyOS 设备体验完成完整的客户端实现。

## 功能特性

- 用户登录与注册
- 基于本地偏好存储的登录态持久化
- 日程创建、查询、更新、删除、归档/完成
- 基于 AI 的自然语言日程解析
- 基于 RDB 的本地日程仓储
- 面向同步场景的本地数据模型，支持待创建、待更新、待删除状态
- 未完成日程数量面板
- 根据未完成日程数量切换动态图标档位
- 在系统动态图标不可用时，提供应用内图标预览降级方案
- 支持 phone、tablet、2in1、wearable 等 HarmonyOS 设备类型配置

## 项目结构

```text
entry/src/main/ets/
|-- common/
|   |-- HttpUtil.ets
|   |-- PreferencesUtil.ets
|   |-- ScheduleModel.ets
|   |-- BreakpointUtil.ets
|   |-- BadgeService.ets
|   `-- DynamicIconService.ets
|-- db/
|   |-- DbHelper.ets
|   |-- ScheduleRepository.ets
|   |-- SyncManager.ets
|   |-- DistributedSyncManager.ets
|   `-- AppStatusStore.ets
|-- pages/
|   |-- LoginPage.ets
|   |-- MainPage.ets
|   |-- ScheduleListPage.ets
|   |-- CreateSchedulePage.ets
|   `-- ScheduleDetailPage.ets
`-- entryability/
    `-- EntryAbility.ets
```

## 技术栈

- HarmonyOS
- ArkTS
- ArkUI
- Stage 模型
- RDB 本地存储
- HTTP API 对接
- AppGallery 动态图标 API

## 后端接口

客户端面向一个日程管理后端，主要对接以下接口：

- `POST /auth/register`
- `POST /auth/login`
- `GET /schedule`
- `POST /schedule`
- `GET /schedule/:id`
- `PUT /schedule/:id`
- `DELETE /schedule/:id`
- `GET /schedule/archive/:id`
- `GET /schedule/quantity`

核心日程字段结构：

```ts
interface ScheduleContent {
  title: string;
  begin_time: string[];
  end_time: string[];
  location: string;
  repeat: string;
  description: string;
}
```

## 动态图标设计

应用会把未完成日程数量映射到四个图标档位：

- `0`：默认图标
- `1-3`：轻量待办
- `4-7`：中等待办
- `8+`：高负载待办

当 AppGallery 动态图标配置不可用时，应用仍会通过应用内状态更新图标预览。

## 开发说明

1. 使用 DevEco Studio 打开项目。
2. 配置本地或线上日程后端的 Base URL。
3. 在 HarmonyOS 设备或模拟器上构建运行。
4. 若要启用系统级动态图标，需要在 AppGallery Connect 中配置图标 ID。

## 安全说明

不要把生产 API Key、LLM Key、Session Secret 或私有后端地址提交到客户端仓库。发布前应将 AI 调用放到后端服务，或使用安全的运行时配置方式。

## 项目状态

这是一个持续开发中的 HarmonyOS 智能日程客户端，适合展示 ArkTS 客户端架构、后端 API 对接、本地持久化、同步处理和 AI 辅助工作流能力。

