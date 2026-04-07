# 后端接口声明

此文档详细说明了后端接口的调用

调试环境下，所有后端接口的调用格式均为 `http:/127.0.0.1:5000/` + 功能url 的格式

## Schedule Routes

`schedule_routes` 的前缀为 /schedule，即所有url都由此前缀开始，上一版的后端接口文档有部分接口未写明此前缀，请注意。

返回值中，大致有如下 key-value 键值对：

+ `schedules: []` 多个日程列表

+ `schedule: {}` 单个日程信息

+ `ids: []` 日程 id 列表

+ `success: bool` 操作是否成功

+ `error: str` 错误信息

### URL: `/schedule`

+ **Methods**: `GET` - 获取所有日程 (not archived)

  + **Response**

    返回所有日程

    ```json
    {
        {
        "schedules": [
          {
            "id": "the id of the schedule",
            "timestamp": "last modified time, in YYYY-MM-DD HH:MM:SS format",
            "type": "schedule",
            "content": {
              "title": "the title of the schedule",
              "content": "the content of the schedule (optional)",
              "whole_day": "bool: whether the schedule is a whole day event",
              "begin_time": ["YYYY-MM-DD", "HH:MM (default 08:00)"],
              "end_time": ["YYYY-MM-DD", "HH:MM (default 23:59)"],
              "location": "the location of the schedule (optional)",
              "remind_before": "the time (in minutes) to remind before the schedule starts (optional)",
              "tag": "the tag of the schedule (optional)",
              "repeat": {
                  "repeat": "bool: whether the schedule is a repeat event",
                  "type": "the type of repeat (e.g., daily, weekly, monthly) (optional)",
                  "every": "the interval of repeat (e.g., 1) (optional)",
                  "repeat_until": ["YYYY-MM-DD", "HH:MM (default 23:59)"]
              },
              "additional_info": [
                  "any additional information related to the schedule (optional)",
                  "this can include links, notes, or any other relevant details",
                  "without any specific format, just plain text"
              ]
            }
          },
          {
            "id": 1
          }
        ]
        }
    }
    ```

+ **Methods**: `POST` - 创建日程

  可以传入多个日程，对于传入日程，检查是否有 `id` 和 `timestamp`。
  
  如果 `id=-1` 或者缺失，则根据已有日程分配一个独一的 `id`；否则使用传入 `id` （暂未实现冲突检测）。

  如果 `timestamp` 缺失，则根据当前时间设置；否则使用传入时间戳。

  + **Requests**

    ```json
    {"schedules": []}
    ```

  + **Response**

    返回成功创建的日程 id （按传入顺序）

    ```json
    {"ids": [1, 2, 3]}
    ```

### URL: `/schedule/<int:id>`

+ **Methods**: `GET` - 根据 `id` 获取单个日程

  + **Response**

    ```json
    {"schedule": {}}
    ```

    注意 "schedule" 为单个日程信息，不用 `[]` 包裹为列表。

+ **Methos**: `PUT` - 根据传入 `schedule` 全量更新（覆盖）本地日程

  + **Requests**

    ```json
    {"schedule": {}}
    ```

  + **Response**

    返回是否成功

    ```json
    {"success": true}
    ```

+ **Methods**: `DELETE` - 根据 `id` 删除日程

  + **Response**

    ```json
    {"success": true}
    ```

### URL: `/schedule/archive/<int:id>`

+ **Methods**: `GET` - 根据 `id` 归档日程（标记完成）

  + **Response**

    ```json
    {"success": true}
    ```

### URL: `/schedule/remind_start`

+ **Methods**: `GET` - 获取设置了每日提醒（从某一日期开始）

  + **Response**

    返回所有已经开始每日提醒的日程

    ```json
    {"schedules": []}
    ```

### URL: `/schedule/remind_before`

+ **Methods**: `GET` - 获取设置了提前提醒（开始时间前提醒）

  + **Response**

    返回所有到达提前提醒时间的日程

    ```json
    {"shedules": {}}
    ```

### URL: `/schedule/sync`

+ **Methods**: `GET` - 同步传入日程

  + **Requests**

    同步传入所有日程，根据 `id` 和 `timestamp` 更新本地日程。

    如果传入日程 `id=-1` 或者 `id` 在已有日程库中无匹配，则按照创建日程逻辑添加本地日程；

    如果传入日程 `timestamp` 较本地时间戳更新，则用传入日程信息 **覆盖** 本地日程

    ```json
    {"schedules": []}
    ```

  + **Response**

    返回同步后的所有本地日程

    ```json
    {"schedules": []}
    ```

### URL: `/schedule/quantity`

+ **Methods**：`GET` - 获取日程数量

  + **Response**

  返回本地存储的日程数量（未归档日程）

  ```json
  {"quantity": 123}
  ```

### URL: `/schedule/quantity/<int:days>`

+ **Methods**: `GET` - 获取 days 天的日程数量

  + **Response**：同上

### URL: `/schedule/titles/<int:days>`

+ **Methods**: `GET` - 获取 days 天的日程标题

  + **Response**

    返回改天的所有未归档日程的标题列表

    ```json
    {"titles": []}
    ```

## Auth Routes

url prefix: `/auth`

实现登录功能后，后端会对前端的每次访问验证 cookie 中的 `user_id`。
如果 cookie 中不包含 `user_id` 信息或者信息不正确，则会直接返回报错信息：

```json
{"success": false, "error": "error infomation"}
```

### URL: `/auth/register`

+ **Methods**: `POST` - 用户注册

  实现用户注册功能，返回注册是否成功；如果失败则包含 `error`

  + **Requests**:

    通过 POST 方法直接传入 `username` 和 `password`

    ```json
    {"username": "user", "password": 123}
    ```

  + **Response**:

    如果成功 (`success=true`) 则不包含报错信息 `error`

    ```json
    {"success": false, "error": "Invalid request method."}
    ```

### URL: `/auth/login`

+ **Methods**: `POST` - 用户登录

  验证 `username` 和 `password`，返回是否登录成功，并在 cookie 中隐式包含 `user_id` 用于后续访问。

  + **Requests**:

    通过 POST 方法直接传入 `username` 和 `password`

    ```json
    {"username": "user", "password": 123}
    ```

  + **Response**:

    如果成功 (`success=true`) 则不包含报错信息 `error`

    ```json
    {"success": false, "error": "Invalid request method."}
    ```

    成功登录后，会在 cookie 中隐式返回 `user_id`，需要在后续范围中携带，否则会认为是未登录。


# 接口说明

以下是针对 `AIScheduler` 类中 `process_user_request` 方法的接口说明文档：

---

# 接口说明：process_user_request

## 基本信息

**接口名称**：处理用户AI请求

**所属类**：`AIScheduler`

**方法签名**：`process_user_request(user_input: Dict) -> Union[Dict, str]`

**版本**：v1.0

**依赖组件**：

- `IntentClassifier`（意图分类器）
- `DeepSeekChat`（大模型对话历史管理）
- `AIScheduleManager`（AI日程管理）

---

## 功能描述

此接口是AI日程调度系统的核心入口，负责：

1. 接收多模态用户输入（文本/语音/图像）
2. 自动识别用户意图（创建/修改/删除/通用对话）
3. 路由到对应的处理逻辑
4. 返回结构化结果或自然语言响应

---

## 请求规范

### 输入参数

| 参数名       | 类型    | 必填 | 描述 |
| `user_input` | `Dict` |   是 | 用户输入字典Dict，包含”image” , ”voice” , ”word ”三项 |

### 输入示例

```python
{
    "word": "请帮我修改周三的会议到周四上午",
    "voice": "", 
    "image": "" 
}

```

---

## 响应规范

### 成功响应

根据意图类型返回不同结构：

### 1. 特定意图响应（CREATE）

```python
        return {
            "status": "success",
            "action": "create",
            "type": schedule_type, # 日志类型: reminder 或 scheduler
            "schedule_data": creation_result,  # 完整的创建数据
        }
```

```python
        if "error" in creation_result:
            return {
                "status": "error",
                "action": "create",
                "error": creation_result["error"] 
                # 返回一个字符串，说明问题
                # 有可能是创建类型无法识别，或者其他导致中断的问题
            }
```

### 2. 特定意图响应（MODIFY）

```python
        return {
            "status": "success",
            "action": "modify",
            "schedule_id": schedule_id, # int类型的id
            "original": original_data, # 完整的原始日志
            "modified": modified_data # 完整的修改后日志
        }
```

```python
        # 如果处理结果中有错误，返回错误信息
        if "error" in modification_result:
            return {
                "status": "error",
                "error": modification_result["error"]
                # 返回 "响应格式无效"
            }
```

### 3. 特定意图响应（DELETE）

```python
        return {
            "status": "success",
            "action": "delete",
            "schedule_id": schedule_id, # 被删除的日志的id（int类型）
            "schedule_title": schedule_title # 被删除日志的title(str类型)
        }
```

```python
        if "error" in deletion_result:
            return {
                "status": "error",
                "action": "delete",
                "error": deletion_result["error"]
                # 返回可能的str类型的错误信息
            }
```

### 4. 特定意图相应（INQUERY）

```python
        return{
            "status": "success",
            "action": "inquery",
            "schedule_list": schedule_list, # 查询到的日程数组（List[Dict])
        }

```

```python
        if "error" in inquery_result:
            return {
                "status": "error",
                "action": "delete",
                "error": inquery_result["error"]
                # 返回可能的str类型的错误信息
            }
```

### 5. 通用对话响应

返回自然语言字符串（str类型）：

```
"已为您将周三的会议调整到周四上午10点"

```

### 错误响应

```python
return "我无法处理您的请求，请稍后再试。"
```

---

## 意图处理逻辑

| 意图类型  | 处理流程 | 典型用户输入 |
| --- | --- | --- |
| `CREATE` | 1. 生成创建提示词. 调用LLM解析. 写入数据库 | "下周一下午3点安排体检" |
| `MODIFY` | 1. 检索现有日程. 生成差异提示. 执行更新 | "把会议改到明天早上" |
| `DELETE` | 1. 识别目标日程. 确认删除 | "取消本周所有会议" |
| `INQUERY` | 1. 识别查询条件，返回对应日程，如果没有条件则返回最近的至多三个日程 | "查询一下我明天的安排"
| `GENERAL` | 1. 语义分析. 生成自然回复 | "我下周有什么安排？" |

---

## 调用示例

### Python调用

```python
scheduler = AIScheduler(app)
response = scheduler.process_user_request(
    {"word": "明天上午10点创建产品评审会"}
)

```

---

## 注意事项

1. 输入字典至少需要包含`word`/`voice`/`image`中的一个字段
2. 系统会自动记录对话历史以实现上下文理解