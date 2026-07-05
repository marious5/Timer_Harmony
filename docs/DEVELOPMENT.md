# Timer_Harmony Development Guide

[简体中文](DEVELOPMENT.zh-CN.md)

This guide summarizes how the repository is organized, how to run the project, and what should be cleaned up next. It is based on the current repository contents.

## Repository Scope

Timer_Harmony contains two major parts:

- HarmonyOS client: ArkTS / ArkUI app under `entry/src/main/ets/`
- Backend service: Flask-based schedule and chat service under `backends/`

The app targets HarmonyOS devices including phone, tablet, 2-in-1, and wearable according to `entry/src/main/module.json5`.

## Client Modules

```text
entry/src/main/ets/
|-- common/
|   |-- HttpUtil.ets              # Backend and AI request layer
|   |-- PreferencesUtil.ets       # Local preference/session helpers
|   |-- ScheduleModel.ets         # Schedule data contracts
|   |-- BreakpointUtil.ets        # Responsive layout utilities
|   |-- BadgeService.ets          # Badge-related service logic
|   `-- DynamicIconService.ets    # Dynamic icon level mapping and fallback preview
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

Main pages are declared in `entry/src/main/resources/base/profile/main_pages.json`.

## Backend Modules

```text
backends/
|-- app/                 # Flask app initialization
|-- config/              # Runtime configuration
|-- core/                # Schedule, auth, and AI-related core logic
|-- routes/              # Flask route definitions
|-- tests/               # Backend tests
|-- data/                # Local development data
`-- requirements.txt
```

Backend dependencies include Flask, OpenAI-compatible client usage, PyYAML, Requests, Pytest, Flask-Session, and Flask-CORS.

## Run the HarmonyOS Client

1. Open the repository in DevEco Studio.
2. Sync/build the HarmonyOS project.
3. Configure the backend base URL used by the client request layer.
4. Run the app on a HarmonyOS device or simulator.

For real-device backend testing, use a LAN-reachable backend address instead of `127.0.0.1`, because the device cannot access the host computer's loopback address directly.

## Run the Backend

From the repository root:

```powershell
cd backends
pip install -r requirements.txt
flask run --host=0.0.0.0
```

The default local backend is usually available at:

```text
http://127.0.0.1:5000
```

When testing from a phone or simulator, replace it with the host machine's LAN IP.

## Configuration

Do not commit real API keys or private service URLs.

The repository uses an example file for the DeepSeek key:

```text
backends/config/deepseek_api_key.example.txt
```

Create your own local-only file when running the backend:

```text
backends/config/deepseek_api_key.txt
```

That real key file is ignored by Git.

## Key Workflows

- Auth: register, login, persist session data locally
- Schedule CRUD: create, list, detail, update, delete
- Completion/archive: mark a schedule as finished or archived
- AI parsing: turn natural-language text into schedule payloads
- Local persistence: keep schedules in RDB-backed storage
- Sync flow: track pending create/update/delete states
- Dynamic icon: map pending count to icon levels and in-app preview state

## Tests

Backend tests live under:

```text
backends/tests/
```

Typical test commands:

```powershell
cd backends
pytest -k "schedule"
pytest -k "chat"
```

AI-related tests may require a valid provider key and network access.

## Screenshot Checklist

When screenshots are ready, prioritize these views:

- Login/register
- Main schedule overview
- Schedule creation with natural-language input
- Schedule detail
- Schedule list
- Dynamic icon or in-app icon preview

Recommended storage path:

```text
docs/assets/
```

Use compressed PNG or WebP files and reference them from `README.md` and `README.zh-CN.md`.

## Next Cleanup Items

- Remove tracked runtime cache files such as `__pycache__` and Flask session data from the repository.
- Add a complete backend API document under `docs/`.
- Move direct AI-provider calls behind a backend endpoint before publishing a production build.
- Add sample `.env` or config templates for local development.

