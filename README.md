# Timer_Harmony

English | [简体中文](README.zh-CN.md)

An intelligent schedule management app for HarmonyOS, built with ArkTS, ArkUI, and the Stage model.

Timer_Harmony focuses on turning natural-language intent into structured schedules, then managing those schedules across local storage, backend APIs, and HarmonyOS device experiences.

## Features

- User login and registration
- Persistent session handling with local preferences
- Schedule creation, reading, updating, deletion, and archive/completion flow
- AI-assisted natural-language parsing for schedule creation
- Local RDB-based schedule repository
- Sync-oriented local data model with pending create/update/delete states
- Pending schedule count panel
- Dynamic app icon level logic based on unfinished schedule quantity
- App icon preview fallback for environments where system-level dynamic icons are unavailable
- HarmonyOS device targets including phone, tablet, 2-in-1, and wearable

## Project Structure

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

## Tech Stack

- HarmonyOS
- ArkTS
- ArkUI
- Stage model
- RDB local storage
- HTTP API integration
- AppGallery dynamic icon API

## Backend API

The client is designed to work with a schedule backend that exposes:

- `POST /auth/register`
- `POST /auth/login`
- `GET /schedule`
- `POST /schedule`
- `GET /schedule/:id`
- `PUT /schedule/:id`
- `DELETE /schedule/:id`
- `GET /schedule/archive/:id`
- `GET /schedule/quantity`

The app keeps backend schedule objects aligned with the following core fields:

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

## Dynamic Icon Design

The app maps unfinished schedule counts into four icon levels:

- `0`: default icon
- `1-3`: light workload icon
- `4-7`: medium workload icon
- `8+`: high workload icon

When AppGallery dynamic icon configuration is unavailable, the app still updates an in-app icon preview through app storage.

## Development Notes

1. Open the project with DevEco Studio.
2. Configure the backend base URL for your local or deployed schedule service.
3. Build and run on a HarmonyOS device or simulator.
4. For system-level dynamic icons, configure the icon IDs in AppGallery Connect before release.

## Security Notes

Do not commit production API keys, LLM keys, session secrets, or private backend addresses into the client repository. Put AI calls behind a backend service or use a secure runtime configuration strategy before publishing.

## Status

This project is an active HarmonyOS client implementation for intelligent schedule management. It is suitable for demonstrating ArkTS client architecture, API integration, local persistence, sync handling, and AI-assisted app workflows.

