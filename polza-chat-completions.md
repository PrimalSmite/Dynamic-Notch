> ## Documentation Index
> Fetch the complete documentation index at: https://polza.ai/docs/llms.txt
> Use this file to discover all available pages before exploring further.

# POST Chat Completions

> Основной эндпоинт для генерации текста и диалогов

Поддерживает текстовые диалоги, мультимодальные запросы (текст + изображения + аудио + видео + файлы), вызов функций и потоковую передачу.

## Возможности

* **Агрегация провайдеров** — автоматический выбор оптимального провайдера
* **Биллинг в рублях** — точный учет стоимости
* **Reasoning Tokens** — поддержка моделей с рассуждениями
* **Streaming** — потоковая передача через SSE
* **Tool Calling** — вызов внешних функций
* **Мультимодальность** — обработка текста, изображений, аудио, видео и файлов

## Параметры запроса

### Обязательные

| Параметр | Тип | Описание |
| - | - | - |
| `model` | string | ID модели из [списка моделей](https://polza.ai/docs/api-reference/models/list.md) |

### Контент

| Параметр | Тип | Описание |
| - | - | - |
| `messages` | array | Массив сообщений диалога (рекомендуется) |
| `prompt` | string | Простой текстовый промпт (альтернатива messages) |

### Параметры генерации

| Параметр | Тип | По умолчанию | Описание |
| - | - | - | - |
| `max_tokens` | integer | Без лимита | Максимум токенов в ответе |
| `max_completion_tokens` | integer | Без лимита | Альтернатива max\_tokens |
| `temperature` | float (0-2) | 1.0 | Температура (0=детерминированный, 2=креативный) |
| `top_p` | float (0-1) | 1.0 | Nucleus sampling |
| `top_k` | integer | — | Top-K sampling |
| `frequency_penalty` | float (-2..2) | 0 | Штраф за повторение слов |
| `presence_penalty` | float (-2..2) | 0 | Штраф за повторение токенов |
| `stop` | string/array | — | Стоп-последовательности |
| `seed` | integer | — | Seed для воспроизводимости |

### Специальные возможности

| Параметр | Тип | Описание |
| - | - | - |
| `stream` | boolean | Включить streaming (SSE) |
| `stream_options` | object | Опции стрима: `include_usage`, `include_server_tool_events` (события серверных инструментов), `hide_intermediate_text` (только финальный ответ) |
| `reasoning` | object | Настройки reasoning tokens |
| `tools` | array | Инструменты: ваши функции (`type: "function"`) и [серверные инструменты](https://polza.ai/docs/gaidy/server-tools.md) Polza (`type: "polza:web_search"` и др.) |
| `tool_choice` | string/object | Выбор инструмента: "none", "auto", "required" |
| `max_tool_calls` | integer (1–30) | Сколько вызовов серверных инструментов модель может сделать за запрос, по умолчанию 10 |
| `stop_server_tools_when` | array | Условия остановки цикла серверных инструментов: `step_count`, `spend_cap` ([подробнее](https://polza.ai/docs/gaidy/server-tools.md#лимиты-вызовов)) |
| `response_format` | object | Формат ответа: text, json\_object, json\_schema, grammar |
| `web_search_options` | object | Веб-поиск: родной поиск провайдера, если модель его поддерживает, иначе поиск Polza ([подробнее](https://polza.ai/docs/gaidy/web-search.md)) |
| `provider` | object | Конфигурация роутинга по провайдерам |
| `plugins` | array | Подключение плагинов |
| `modalities` | array | Выходные модальности: "text", "image", "audio" |
| `audio` | object | Конфигурация аудио-вывода (voice, format) |
| `user` | string | Идентификатор конечного пользователя |

## Структура сообщений

### Базовый формат

```json theme={null}
{
  "role": "user|assistant|system|developer|tool",
  "content": "Текст сообщения"
}
```

### Мультимодальные сообщения

```json theme={null}
{
  "role": "user",
  "content": [
    {"type": "text", "text": "Что на этом изображении?"},
    {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}}
  ]
}
```

### Другие типы контента

```json theme={null}
// Аудио вход
{"type": "input_audio", "input_audio": {"data": "base64...", "format": "mp3"}}

// Видео вход
{"type": "video_url", "video_url": {"url": "https://example.com/video.mp4"}}

// Файл
{"type": "file", "file": {"filename": "doc.pdf", "file_data": "data:application/pdf;base64,..."}}
```

### Системные сообщения с кешированием

```json theme={null}
{
  "role": "system",
  "content": [
    {
      "type": "text",
      "text": "Длинная системная инструкция...",
      "cache_control": {"type": "ephemeral"}
    }
  ]
}
```

## Примеры

```bash cURL theme={null}
curl -X POST "https://polza.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-4o",
    "messages": [{"role": "user", "content": "Привет!"}]
  }'
```

```python Python theme={null}
from openai import OpenAI

client = OpenAI(
    base_url="https://polza.ai/api/v1",
    api_key="YOUR_API_KEY"
)

response = client.chat.completions.create(
    model="anthropic/claude-sonnet-4-5-20250929",
    messages=[{"role": "user", "content": "Объясни квантовую механику"}]
)

print(response.choices[0].message.content)
print(f"Стоимость: {response.usage.cost_rub} руб.")
```

```typescript TypeScript theme={null}
import OpenAI from 'openai';

const client = new OpenAI({
    baseURL: 'https://polza.ai/api/v1',
    apiKey: 'YOUR_API_KEY'
});

const response = await client.chat.completions.create({
    model: 'openai/gpt-4o',
    messages: [{role: 'user', content: 'Напиши историю'}],
    stream: true
});

for await (const chunk of response) {
    process.stdout.write(chunk.choices[0]?.delta?.content || '');
}
```

## Ответ

### Успешный ответ (200)

```json theme={null}
{
  "id": "gen_581761234567890123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "openai/gpt-4o",
  "provider": "OpenAI",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Текст ответа"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 25,
    "completion_tokens": 150,
    "total_tokens": 175,
    "cost_rub": 0.04131306,
    "cost": 0.04131306,
    "prompt_tokens_details": {
      "cached_tokens": 0
    },
    "completion_tokens_details": {
      "reasoning_tokens": 0
    }
  }
}
```

### Streaming (SSE)

При `stream: true` ответ приходит в формате Server-Sent Events:

```
data: {"id":"gen_123","object":"chat.completion.chunk","created":1703001234,"model":"openai/gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","content":"Привет"}}]}

data: {"id":"gen_123","object":"chat.completion.chunk","created":1703001234,"model":"openai/gpt-4o","choices":[{"index":0,"delta":{"content":" мир"}}]}

data: {"id":"gen_123","object":"chat.completion.chunk","created":1703001234,"model":"openai/gpt-4o","choices":[],"usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30,"cost_rub":0.015,"cost":0.015}}

data: [DONE]
```

## Tool Calling

### Определение функций

```json theme={null}
{
  "tools": [{
    "type": "function",
    "function": {
      "name": "get_weather",
      "description": "Получить текущую погоду",
      "parameters": {
        "type": "object",
        "properties": {
          "city": {"type": "string"}
        },
        "required": ["city"]
      }
    }
  }],
  "tool_choice": "auto"
}
```

### Серверные инструменты

Инструменты, которые выполняет Polza внутри одного запроса, — поиск, чтение страниц, дата и время. Модель вызывает их сама, вы получаете готовый ответ:

```json theme={null}
{
  "tools": [
    {"type": "polza:web_search", "parameters": {"max_results": 3}},
    {"type": "polza:datetime", "parameters": {"timezone": "Europe/Moscow"}}
  ],
  "max_tool_calls": 5
}
```

Список инструментов, ответ и стриминг — в гайде [Серверные инструменты](https://polza.ai/docs/gaidy/server-tools.md).

### Ответ модели с вызовом функции

```json theme={null}
{
  "tool_calls": [{
    "id": "call_123",
    "function": {"name": "get_weather", "arguments": "{\"city\": \"Москва\"}"}
  }]
}
```

## Response Format

### JSON Schema (структурированный вывод)

```json theme={null}
{
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "my_schema",
      "schema": {
        "type": "object",
        "properties": {
          "answer": {"type": "string"},
          "confidence": {"type": "number"}
        }
      },
      "strict": true
    }
  }
}
```

Поддерживаемые типы: `text`, `json_object`, `json_schema`, `grammar` (GBNF).

## Reasoning Tokens

Для моделей с рассуждениями (o1, o3, DeepSeek-R1 и другие):

```json theme={null}
{
  "model": "openai/o1-preview",
  "messages": [{"role": "user", "content": "Реши: 2x + 5 = 13"}],
  "reasoning": {
    "effort": "high",
    "max_tokens": 1000
  }
}
```

### Параметры reasoning

| Параметр | Тип | Описание |
| - | - | - |
| `effort` | string | Уровень усилий: xhigh, high, medium, low, minimal, none |
| `max_tokens` | integer | Максимум токенов на рассуждения |
| `summary` | string | Детализация: auto, concise, detailed |
| `enabled` | boolean | Включить/выключить рассуждения |
| `exclude` | boolean | Скрыть рассуждения из ответа |


## OpenAPI

````yaml POST /v1/chat/completions
openapi: 3.0.0
info:
  title: Polza.ai API
  description: AI агрегатор — унифицированный доступ к сотням AI моделей
  version: '1.0'
  contact: {}
servers:
  - url: https://polza.ai/api
    description: Production
security: []
tags: []
paths:
  /v1/chat/completions:
    post:
      tags:
        - Чат
      summary: Создать chat completion
      operationId: ChatController_createChatCompletion[1]
      parameters: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ChatCompletionRequestDto'
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ChatCompletionPresenter'
        '400':
          description: Некорректный запрос. Проверьте параметры и тело
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '401':
          description: Ошибка авторизации. Проверьте ключ доступа
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '402':
          description: Недостаточно средств или достигнут лимит
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '403':
          description: Ошибка доступа. Проверьте права доступа ключа
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '404':
          description: Ресурс не найден
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '408':
          description: Истекло время ожидания ответа. Повторите запрос
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '409':
          description: Конфликт состояния. Перечитайте ресурс и повторите запрос
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '413':
          description: Размер тела запроса превышает допустимый предел
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '429':
          description: Слишком много запросов. Повторите позже
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '500':
          description: Ошибка сервера. Обратитесь к поставщику услуг
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '502':
          description: Поставщик услуг вернул некорректный ответ
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
        '503':
          description: Сервис временно недоступен. Повторите позже
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiErrorPresenter'
      security:
        - bearer: []
components:
  schemas:
    ChatCompletionRequestDto:
      type: object
      properties:
        model:
          type: string
          description: >-
            Идентификатор модели. Для Chat Completions API поддерживается
            alias-формат <model>@<key>=<value>&<key>=<value>. Поддерживаемые
            ключи: provider, reasoning_effort, allow_fallbacks, data_residency.
            При конфликте alias и обычных полей body API возвращает 400. Для
            некоторых провайдеров и моделей допустимые значения reasoning_effort
            отличаются; например, Yandex AI Studio поддерживает только low,
            medium и high.
          example: >-
            openai/gpt-4o@provider=google&reasoning_effort=high&allow_fallbacks=false
        prompt:
          type: string
          description: >-
            Текстовый промпт (альтернатива messages). Если указан, будет
            преобразован в messages с role=user
          example: Напиши стихотворение про кота
        messages:
          description: >-
            Массив сообщений для отправки модели (обязателен если не указан
            prompt)
          example:
            - role: system
              content: Ты полезный ассистент
            - role: user
              content: Привет! Как дела?
          type: array
          items:
            $ref: '#/components/schemas/MessageDto'
        max_tokens:
          type: number
          description: Максимальное количество токенов для генерации
          example: 1000
          minimum: 1
        max_completion_tokens:
          type: number
          description: >-
            Максимальное количество токенов для completion (альтернатива
            max_tokens)
          example: 1000
          minimum: 1
        temperature:
          type: number
          description: >-
            Температура сэмплинга (0-2). Более высокие значения делают вывод
            более случайным
          example: 1
          minimum: 0
          maximum: 2
        top_p:
          type: number
          description: 'Nucleus sampling: вероятностная масса для рассмотрения (0-1)'
          example: 1
          minimum: 0
          maximum: 1
        frequency_penalty:
          type: number
          description: Штраф за частоту использования токенов (-2 до 2)
          example: 0
          minimum: -2
          maximum: 2
        presence_penalty:
          type: number
          description: Штраф за присутствие токенов (-2 до 2)
          example: 0
          minimum: -2
          maximum: 2
        response_format:
          type: object
          description: Формат ответа модели
        provider:
          description: Настройки провайдера для роутинга и фильтрации
          allOf:
            - $ref: '#/components/schemas/ProviderDto'
        tools:
          type: array
          description: >-
            Инструменты: функции (type: function) исполняет ваш код; серверные
            (type: polza:*) исполняет Polza внутри запроса
          items:
            oneOf:
              - $ref: '#/components/schemas/ToolDefinitionDto'
              - $ref: '#/components/schemas/ServerToolDefinitionDto'
        max_tool_calls:
          type: integer
          description: >-
            Максимум вызовов серверных инструментов за запрос (по умолчанию 10,
            потолок 30; без polza:* игнорируется)
          example: 10
          minimum: 1
          maximum: 30
        stop_server_tools_when:
          description: >-
            Условия остановки цикла серверных инструментов: step_count заменяет
            max_tool_calls (потолок 30), spend_cap добавляет мягкий потолок
            расходов на запрос: он проверяется перед каждым шагом модели,
            поэтому итог может превысить spend_cap на шаг, на котором потолок
            пройден, его инструменты и финальный ответ
          type: array
          items:
            $ref: '#/components/schemas/StopServerToolsWhenDto'
        stream_options:
          description: Опции стриминга
          allOf:
            - $ref: '#/components/schemas/ChatStreamOptionsDto'
        tool_choice:
          description: >-
            Выбор инструмента: режим none, auto, required (строкой или объектом
            `{type}`), named function или серверный инструмент `{type:
            "polza:<инструмент>"}`
          oneOf:
            - type: string
              enum:
                - none
                - auto
                - required
            - type: object
              properties:
                type:
                  type: string
                  enum:
                    - none
                    - auto
                    - required
              required:
                - type
            - $ref: '#/components/schemas/NamedToolChoiceDto'
            - type: object
              description: Вызов серверного инструмента из tools
              properties:
                type:
                  type: string
                  pattern: '^polza:'
                  example: polza:web_search
              required:
                - type
          example: auto
        reasoning:
          description: Настройки reasoning для reasoning моделей
          allOf:
            - $ref: '#/components/schemas/ReasoningDto'
        plugins:
          type: array
          description: Плагины для расширения функциональности
        web_search_options:
          description: >-
            Веб-поиск для любой модели. Модель с родным поиском у провайдера
            (Возможность native_web_search) ищет сама. Иначе ищет Polza:
            серверным инструментом polza:web_search, если модель умеет tool
            calling и организации доступны серверные инструменты, или поиском до
            вызова модели. Если веб-поиск через Polza выключен на сервере,
            параметр передаётся провайдеру как есть
          allOf:
            - $ref: '#/components/schemas/WebSearchOptionsDto'
        user:
          type: string
          description: >-
            Уникальный идентификатор конечного пользователя для отслеживания и
            предотвращения злоупотреблений
          example: user-123
          maxLength: 256
        stop:
          description: Последовательности, при которых модель прекращает генерацию
          example:
            - |+

          oneOf:
            - type: string
            - type: array
              items:
                type: string
        seed:
          type: number
          description: Seed для детерминированной генерации (best-effort)
          example: 42
        'n':
          type: number
          description: Количество вариантов ответа (1-10)
          example: 1
          minimum: 1
          maximum: 10
        stream:
          type: boolean
          description: Включить потоковую передачу ответа
          example: false
        logprobs:
          type: boolean
          description: Возвращать log probabilities для output токенов
          example: false
        top_logprobs:
          type: number
          description: >-
            Количество наиболее вероятных токенов для возврата (0-20). Требует
            logprobs: true
          example: 5
          minimum: 0
          maximum: 20
        logit_bias:
          type: object
          description: Смещение вероятностей токенов по их ID (-100 до 100)
          example:
            '50256': -100
        parallel_tool_calls:
          type: boolean
          description: Разрешить параллельный вызов нескольких tools
          example: true
        prompt_cache_key:
          type: string
          description: >-
            Ключ серии запросов с общим началом: запросы с одним ключом идут к
            тому же провайдеру, чтобы попадать в его кэш
          example: agent-42
        prompt_cache_options:
          description: Настройки кэша начала запроса (OpenAI)
          example:
            ttl: 12h
          allOf:
            - $ref: '#/components/schemas/PromptCacheOptionsDto'
        image_config:
          type: object
          description: Настройки обработки изображений
          example:
            quality: high
            size: 512
        media_resolution:
          type: string
          description: >-
            Разрешение обработки медиа для google/gemini-* моделей (Gemini
            media_resolution). Допустимые значения: MEDIA_RESOLUTION_LOW,
            MEDIA_RESOLUTION_MEDIUM, MEDIA_RESOLUTION_HIGH,
            MEDIA_RESOLUTION_UNSPECIFIED. Для остальных моделей игнорируется.
          example: MEDIA_RESOLUTION_LOW
        modalities:
          type: array
          description: Типы вывода модели
          example:
            - text
            - audio
          items:
            type: string
            enum:
              - text
              - image
              - audio
        audio:
          type: object
          description: >-
            Настройки аудио выхода для моделей с поддержкой аудио (gpt-audio и
            др.)
          properties:
            voice:
              type: string
              example: alloy
              description: Голос для генерации аудио
            format:
              type: string
              example: pcm16
              description: Формат аудио
      required:
        - model
        - messages
    ChatCompletionPresenter:
      type: object
      properties:
        id:
          type: string
          description: Уникальный идентификатор генерации
          example: gen_581761234567890123
        object:
          type: string
          description: Тип объекта
          example: chat.completion
        created:
          type: number
          description: Временная метка создания (Unix timestamp)
          example: 1703001234
        model:
          type: string
          description: ID модели, которая сгенерировала ответ
          example: openai/gpt-4o
        choices:
          description: Массив вариантов ответа
          type: array
          items:
            $ref: '#/components/schemas/ChoicePresenter'
        provider:
          type: string
          description: Провайдер обработавший запрос
          example: openai-direct
        system_fingerprint:
          type: string
          description: System fingerprint от провайдера
          example: fp_29330a9688
        usage:
          description: Информация об использовании токенов
          allOf:
            - $ref: '#/components/schemas/UsagePresenter'
        polza:
          type: object
          description: >-
            Есть, если модель вызывала серверные инструменты:
            parent_generation_id — id запроса в истории (GET
            /v1/history/generations/{id}), шаги — /children
          example:
            parent_generation_id: gen_…
      required:
        - id
        - object
        - created
        - model
        - choices
    ApiErrorPresenter:
      type: object
      properties:
        error:
          description: Информация об ошибке
          allOf:
            - $ref: '#/components/schemas/ApiErrorBodyPresenter'
        trace_id:
          type: string
          description: ID трассировки запроса
          example: 550e8400-e29b-41d4-a716-446655440000
      required:
        - error
    MessageDto:
      type: object
      properties:
        role:
          type: string
          description: Роль отправителя сообщения
          enum:
            - user
            - assistant
            - system
            - developer
            - tool
          example: user
        content:
          description: >-
            Содержимое сообщения: строка, массив частей контента или null для
            assistant с tool_calls. Часть массива — объект с полем type из
            списка: text, refusal, image_url, input_audio, video_url,
            input_video, file, document, search_result; вложенные массивы и
            части-строки не принимаются
          oneOf:
            - type: string
              example: Привет, как дела?
            - type: array
              items:
                oneOf:
                  - type: object
                    required:
                      - type
                      - text
                    properties:
                      type:
                        type: string
                        enum:
                          - text
                      cache_control:
                        type: object
                        required:
                          - type
                        properties:
                          type:
                            type: string
                            enum:
                              - ephemeral
                          ttl:
                            type: string
                            enum:
                              - 5m
                              - 1h
                      text:
                        type: string
                  - type: object
                    required:
                      - type
                      - refusal
                    properties:
                      type:
                        type: string
                        enum:
                          - refusal
                      refusal:
                        type: string
                  - type: object
                    required:
                      - type
                      - image_url
                    properties:
                      type:
                        type: string
                        enum:
                          - image_url
                      video_metadata:
                        type: object
                        properties:
                          fps:
                            type: number
                          start_offset:
                            type: string
                          end_offset:
                            type: string
                      image_url:
                        type: object
                        properties:
                          url:
                            type: string
                          detail:
                            type: string
                            enum:
                              - auto
                              - low
                              - high
                        required:
                          - url
                  - type: object
                    required:
                      - type
                      - input_audio
                    properties:
                      type:
                        type: string
                        enum:
                          - input_audio
                      input_audio:
                        type: object
                        properties:
                          data:
                            type: string
                          format:
                            type: string
                        required:
                          - data
                          - format
                  - type: object
                    required:
                      - type
                      - video_url
                    properties:
                      type:
                        type: string
                        enum:
                          - video_url
                      video_metadata:
                        type: object
                        properties:
                          fps:
                            type: number
                          start_offset:
                            type: string
                          end_offset:
                            type: string
                      video_url:
                        type: object
                        properties:
                          url:
                            type: string
                        required:
                          - url
                  - type: object
                    required:
                      - type
                      - video_url
                    properties:
                      type:
                        type: string
                        enum:
                          - input_video
                      video_metadata:
                        type: object
                        properties:
                          fps:
                            type: number
                          start_offset:
                            type: string
                          end_offset:
                            type: string
                      video_url:
                        type: object
                        properties:
                          url:
                            type: string
                        required:
                          - url
                  - type: object
                    required:
                      - type
                      - file
                    properties:
                      type:
                        type: string
                        enum:
                          - file
                      video_metadata:
                        type: object
                        properties:
                          fps:
                            type: number
                          start_offset:
                            type: string
                          end_offset:
                            type: string
                      file:
                        type: object
                        properties:
                          file_data:
                            type: string
                          url:
                            type: string
                          filename:
                            type: string
                            example: document.pdf
                        anyOf:
                          - required:
                              - file_data
                          - required:
                              - url
                  - type: object
                    required:
                      - type
                    properties:
                      type:
                        type: string
                        enum:
                          - document
                  - type: object
                    required:
                      - type
                    properties:
                      type:
                        type: string
                        enum:
                          - search_result
          nullable: true
        name:
          type: string
          description: Имя отправителя (опционально)
          example: Иван
        tool_call_id:
          type: string
          description: ID вызова инструмента (только для role=tool)
          example: call_abc123
        tool_calls:
          description: Массив вызовов инструментов (только для role=assistant)
          type: array
          items:
            $ref: '#/components/schemas/ToolCallDto'
        refusal:
          type: object
          description: >-
            Текст отказа модели от выполнения запроса (только для
            role=assistant)
          example: Я не могу помочь с этим запросом
          nullable: true
        reasoning:
          type: object
          description: Reasoning текст для моделей с reasoning (только для role=assistant)
          example: Для решения этой задачи мне нужно...
          nullable: true
        reasoning_content:
          type: object
          description: Текст reasoning в формате DeepSeek
          example: Проверяю условия
          nullable: true
        reasoning_details:
          description: Структурированные детали reasoning для повторной отправки
          type: array
          items:
            $ref: '#/components/schemas/ReasoningDetailDto'
        annotations:
          type: array
          description: >-
            Аннотации из ответа провайдера (для кэширования парсинга PDF и
            других документов)
          items:
            type: object
      required:
        - role
        - content
    ProviderDto:
      type: object
      properties:
        require_parameters:
          type: boolean
          description: Требовать от провайдера поддержку всех переданных параметров
          example: true
        allow_fallbacks:
          type: boolean
          description: Разрешить использование резервных провайдеров
          example: true
        order:
          description: Упорядоченный список slug провайдеров для использования
          example:
            - OpenAI
            - Anthropic
          type: array
          items:
            type: string
        only:
          description: Список разрешенных slug провайдеров
          example:
            - OpenAI
            - Google
          type: array
          items:
            type: string
        ignore:
          description: Список игнорируемых slug провайдеров
          example:
            - DeepInfra
          type: array
          items:
            type: string
        sort:
          type: string
          description: Критерий сортировки провайдеров
          enum:
            - price
            - throughput
            - latency
          example: price
        data_residency:
          type: string
          description: >-
            Где должны обрабатываться данные запроса. `ru` — только провайдеры
            на инфраструктуре в РФ, в том числе при fallback. Если таких
            провайдеров у модели нет, запрос отклоняется, а не уходит к
            иностранному провайдеру. Распознавание PDF (OCR) плагина
            polza-pdf-parser при `ru` отключается: текст извлекается без него.
            Инструменты, которые клиент включает сам (веб-поиск, web_fetch),
            параметр не ограничивает: они обращаются к внешним сервисам
          enum:
            - ru
          example: ru
        max_price:
          description: Максимальные цены для запроса
          allOf:
            - $ref: '#/components/schemas/ProviderMaxPriceDto'
    ToolDefinitionDto:
      type: object
      properties:
        type:
          type: string
          description: Тип инструмента
          example: function
          enum:
            - function
        function:
          description: Определение функции
          allOf:
            - $ref: '#/components/schemas/ToolFunctionDto'
      required:
        - type
        - function
    ServerToolDefinitionDto:
      type: object
      properties:
        type:
          type: string
          description: >-
            Тип серверного инструмента с префиксом polza: (openrouter:
            принимается как алиас); список — GET /v1/server-tools
          example: polza:web_search
        parameters:
          type: object
          description: >-
            Параметры инструмента по его parameters_schema из GET
            /v1/server-tools (например max_results, max_uses для
            polza:web_search). В Responses API параметры можно передать и рядом
            с type
          example:
            max_results: 5
            max_uses: 3
      required:
        - type
    StopServerToolsWhenDto:
      type: object
      properties:
        type:
          type: string
          description: Тип условия
          enum:
            - step_count
            - spend_cap
          example: step_count
        value:
          type: number
          description: >-
            Для step_count: максимум вызовов серверных инструментов (больше 30 —
            считается как 30)
          example: 5
        value_rub:
          type: number
          description: >-
            Для spend_cap: потолок расходов на запрос (модель и инструменты),
            RUB
          example: 20
      required:
        - type
    ChatStreamOptionsDto:
      type: object
      properties:
        include_usage:
          type: boolean
          description: Отдавать usage в финальном чанке (совместимость OpenAI)
          example: true
        include_server_tool_events:
          type: boolean
          description: >-
            Отдавать события цикла серверных инструментов (tool_call,
            tool_result, step_end, budget_exhausted) полем `polza` в чанках
          example: false
        hide_intermediate_text:
          type: boolean
          description: >-
            Не отдавать текст промежуточных шагов цикла серверных инструментов
            («Сейчас поищу…»); финальный ответ приходит одним куском после
            завершения шага. Только для stream
          example: false
    NamedToolChoiceDto:
      type: object
      properties:
        type:
          type: string
          description: Тип инструмента
          example: function
          enum:
            - function
        function:
          description: Выбранная функция
          allOf:
            - $ref: '#/components/schemas/NamedToolChoiceFunctionDto'
      required:
        - type
        - function
    ReasoningDto:
      type: object
      properties:
        type:
          type: string
          description: >-
            Тип reasoning: adaptive — автовыбор глубины (Claude 4.6+), disabled
            — отключить. Для Claude 4.6+ используйте adaptive вместо
            enabled+max_tokens
          enum:
            - adaptive
            - disabled
          example: adaptive
        effort:
          type: string
          description: >-
            Уровень усилий reasoning модели. Для некоторых провайдеров и моделей
            допустимые значения могут отличаться. Проверяйте документацию
            конкретного провайдера. Например, для Yandex AI Studio
            поддерживаются только low, medium и high.
          enum:
            - max
            - xhigh
            - high
            - medium
            - low
            - minimal
            - none
          example: medium
        effort_level:
          type: string
          description: >-
            Уровень усилий для adaptive thinking (Claude 4.6+). Значение max
            даёт максимальную глубину мышления. Используется вместо effort для
            Claude 4.6+ моделей
          example: max
        summary:
          type: string
          description: Уровень детализации резюме reasoning
          enum:
            - auto
            - concise
            - detailed
            - none
          example: auto
        enabled:
          type: boolean
          description: >-
            Включить/выключить reasoning. По умолчанию определяется из effort
            или max_tokens
          example: true
        max_tokens:
          type: number
          description: Максимальное количество токенов для reasoning (стиль Anthropic)
          example: 2000
        exclude:
          type: boolean
          description: >-
            Скрыть reasoning из ответа (модель будет использовать reasoning, но
            не вернёт его)
          example: false
    WebSearchOptionsDto:
      type: object
      properties:
        search_context_size:
          type: string
          description: Принимается для совместимости с OpenAI и на поиск Polza не влияет
          enum:
            - low
            - medium
            - high
          example: medium
    PromptCacheOptionsDto:
      type: object
      properties:
        ttl:
          type: string
          description: >-
            Сколько хранить кэш начала запроса у OpenAI: 30m — около 30 минут
            (по умолчанию), 12h — не меньше 12 часов. Запись в 12-часовой кэш
            стоит вдвое дороже обычной записи, чтение — как обычно. Другие
            провайдеры поле не используют.
          enum:
            - 30m
            - 12h
          example: 12h
      required:
        - ttl
    ChoicePresenter:
      type: object
      properties:
        index:
          type: number
          description: Индекс выбора в массиве choices
          example: 0
        message:
          description: Сообщение от модели
          allOf:
            - $ref: '#/components/schemas/MessagePresenter'
        finish_reason:
          type: string
          description: Причина завершения генерации
          example: stop
          enum:
            - stop
            - length
            - content_filter
            - error
            - tool_calls
          nullable: true
        reasoning_details:
          type: array
          description: Детали reasoning процесса (для reasoning моделей)
        logprobs:
          description: Log probabilities для токенов
          nullable: true
          allOf:
            - $ref: '#/components/schemas/ChatMessageTokenLogprobsPresenter'
      required:
        - index
        - message
        - finish_reason
    UsagePresenter:
      type: object
      properties:
        prompt_tokens:
          type: number
          description: Количество токенов в промпте
          example: 10
        completion_tokens:
          type: number
          description: Количество токенов в ответе
          example: 50
        total_tokens:
          type: number
          description: Общее количество токенов (prompt + completion)
          example: 60
        completion_tokens_details:
          description: Детализация токенов completion
          nullable: true
          allOf:
            - $ref: '#/components/schemas/CompletionTokensDetailsPresenter'
        prompt_tokens_details:
          description: Детализация токенов промпта
          nullable: true
          allOf:
            - $ref: '#/components/schemas/PromptTokensDetailsPresenter'
        server_tool_use:
          description: >-
            Число исполненных вызовов серверных инструментов по типам:
            web_search_requests, web_fetch_requests, datetime_requests, …
          nullable: true
          allOf:
            - $ref: '#/components/schemas/ServerToolUsePresenter'
        cost_rub:
          type: object
          description: Стоимость запроса в рублях (списано с баланса клиента)
          example: 0.04131306
          nullable: true
        cost:
          type: object
          description: Стоимость запроса в рублях (alias для cost_rub)
          example: 0.04131306
          nullable: true
        cost_details:
          type: object
          description: >-
            Разбивка cost_rub запроса с серверными инструментами: модель (все
            шаги) и инструменты, RUB
          example:
            inference_cost_rub: 1.2
            server_tools_cost_rub: 0.4
          nullable: true
        server_tool_use_details:
          type: object
          description: >-
            Детали цикла серверных инструментов: исполненные вызовы по типам,
            запрошенные и исполненные вызовы всего, число шагов модели
          example:
            web_search_requests: 1
            tool_calls_requested: 2
            tool_calls_executed: 2
            steps: 2
          nullable: true
        plugins:
          type: object
          description: Детализация серверных плагинов
          example:
            masker:
              operations:
                - operation: mask
                  latency_ms: 15
                  cost_rub: 0.001
                - operation: unmask
                  latency_ms: 8
                  cost_rub: 0
              total_cost_rub: 0.001
          nullable: true
        plugin_post_process_error:
          type: boolean
          description: >-
            Ошибка post-process плагинов (ответ возвращён в замаскированном
            виде)
          example: true
        guard:
          description: >-
            Проверка запроса политикой защиты данных организации; нет поля —
            политика к ключу не назначена
          allOf:
            - $ref: '#/components/schemas/GuardUsagePresenter'
      required:
        - prompt_tokens
        - completion_tokens
        - total_tokens
    ApiErrorBodyPresenter:
      type: object
      properties:
        code:
          type: string
          description: Код ошибки
          enum:
            - BAD_REQUEST
            - UNAUTHORIZED
            - api_key_revoked
            - INSUFFICIENT_BALANCE
            - FORBIDDEN
            - guard_no_route
            - guard_blocked
            - unofficial_providers_disabled
            - NOT_FOUND
            - REQUEST_TIMEOUT
            - CONFLICT
            - PAYLOAD_TOO_LARGE
            - TOO_MANY_REQUESTS
            - BAD_GATEWAY
            - SERVICE_UNAVAILABLE
            - INTERNAL_ERROR
          example: BAD_REQUEST
        message:
          type: string
          description: Описание ошибки
          example: Недопустимое значение параметра
        trace_id:
          type: string
          description: ID трассировки запроса
          example: 550e8400-e29b-41d4-a716-446655440000
        details:
          type: object
          description: Уточняющие поля ошибки. Отдаются только для 4xx
          additionalProperties: true
        metadata:
          description: Метаданные ошибки провайдера
          allOf:
            - $ref: '#/components/schemas/ApiErrorMetadataPresenter'
      required:
        - code
        - message
    ToolCallDto:
      type: object
      properties:
        extra_content:
          description: Подпись вызова провайдера
          allOf:
            - $ref: '#/components/schemas/ToolCallExtraContentDto'
        id:
          type: string
          description: Уникальный идентификатор вызова инструмента
          example: call_abc123xyz
        type:
          type: string
          description: Тип вызова инструмента
          enum:
            - function
          example: function
        function:
          description: Информация о вызываемой функции
          allOf:
            - $ref: '#/components/schemas/ToolCallFunctionDto'
      required:
        - id
        - type
        - function
    ReasoningDetailDto:
      type: object
      properties:
        type:
          type: string
          description: Тип детали reasoning
          example: reasoning.text
        index:
          type: number
          description: Индекс детали в ответе провайдера
          example: 0
        id:
          type: object
          description: Исходный ID reasoning
          example: rs_123
          nullable: true
        text:
          type: string
          description: Текст рассуждений
          example: Проверяю условия задачи
        summary:
          type: string
          description: Краткое описание рассуждений
          example: Нужен результат инструмента
        signature:
          type: object
          description: Подпись рассуждений провайдера
          example: opaque-signature
          nullable: true
        data:
          type: string
          description: Непрозрачные зашифрованные данные провайдера
          example: opaque-data
        format:
          type: string
          description: Формат reasoning провайдера
          example: anthropic-claude-v1
      required:
        - type
    ProviderMaxPriceDto:
      type: object
      properties:
        prompt:
          type: number
          description: Максимальная цена за промпт токены (RUB за миллион токенов)
          example: 10
        completion:
          type: number
          description: Максимальная цена за completion токены (RUB за миллион токенов)
          example: 20
        image:
          type: number
          description: Максимальная цена за изображение (RUB за штуку)
          example: 5
        audio:
          type: number
          description: Максимальная цена за аудио (RUB за миллион токенов)
          example: 15
        request:
          type: number
          description: Максимальная цена за запрос (RUB за запрос)
          example: 1
        video_per_second:
          type: number
          description: Максимальная цена за секунду видео (RUB за секунду)
          example: 50
        stt_per_minute:
          type: number
          description: Максимальная цена распознавания речи (RUB за минуту)
          example: 5
        tts_per_million_characters:
          type: number
          description: Максимальная цена синтеза речи (RUB за миллион символов)
          example: 1500
    ToolFunctionDto:
      type: object
      properties:
        name:
          type: string
          description: Название функции
          example: get_weather
        description:
          type: string
          description: Описание функции
          example: Получить текущую погоду для указанного местоположения
        parameters:
          type: object
          description: JSON Schema параметров функции
          example:
            type: object
            properties:
              location:
                type: string
                description: Название города
              unit:
                type: string
                enum:
                  - celsius
                  - fahrenheit
            required:
              - location
        strict:
          type: boolean
          description: Строгое соответствие схеме
          example: false
      required:
        - name
    NamedToolChoiceFunctionDto:
      type: object
      properties:
        name:
          type: string
          description: Название функции для вызова
          example: get_weather
      required:
        - name
    MessagePresenter:
      type: object
      properties:
        role:
          type: string
          description: Роль отправителя сообщения
          example: assistant
        content:
          type: object
          description: Содержимое сообщения
          example: Привет! Я хорошо, спасибо что спросили. Чем могу помочь?
          nullable: true
        name:
          type: object
          description: Имя отправителя
          example: Ассистент
          nullable: true
        tool_calls:
          description: Вызовы инструментов (tool calls)
          type: array
          items:
            $ref: '#/components/schemas/ToolCallPresenter'
        refusal:
          type: object
          description: Отказ модели от выполнения запроса
          example: null
          nullable: true
        reasoning:
          type: object
          description: Reasoning текст (для reasoning моделей)
          example: null
          nullable: true
        reasoning_details:
          description: Детали reasoning для повторной отправки истории
          type: array
          items:
            $ref: '#/components/schemas/ReasoningDetailPresenter'
        audio:
          type: object
          description: Аудио данные (для моделей с audio output)
          properties:
            id:
              type: string
              description: ID аудио
            data:
              type: string
              description: Base64-encoded аудио данные
            transcript:
              type: string
              description: Текстовая расшифровка
            expires_at:
              type: number
              description: Unix timestamp истечения
        annotations:
          type: array
          description: Аннотации (ссылки на источники от web search)
          items:
            type: object
      required:
        - role
        - content
    ChatMessageTokenLogprobsPresenter:
      type: object
      properties:
        content:
          description: Log probabilities для контента
          nullable: true
          type: array
          items:
            $ref: '#/components/schemas/ChatMessageTokenLogprobPresenter'
        refusal:
          description: Log probabilities для refusal
          nullable: true
          type: array
          items:
            $ref: '#/components/schemas/ChatMessageTokenLogprobPresenter'
      required:
        - content
        - refusal
    CompletionTokensDetailsPresenter:
      type: object
      properties:
        reasoning_tokens:
          type: object
          description: Токены reasoning (для reasoning моделей)
          example: 100
          nullable: true
        audio_tokens:
          type: object
          description: Аудио токены в ответе
          example: 0
          nullable: true
        image_tokens:
          type: object
          description: Токены изображений в ответе
          example: 0
          nullable: true
        accepted_prediction_tokens:
          type: object
          description: Принятые токены предсказаний
          example: 0
          nullable: true
        rejected_prediction_tokens:
          type: object
          description: Отклоненные токены предсказаний
          example: 0
          nullable: true
    PromptTokensDetailsPresenter:
      type: object
      properties:
        cached_tokens:
          type: number
          description: Кэшированные токены
          example: 0
        cache_write_tokens:
          type: number
          description: Токены, записанные в prompt cache
          example: 0
        audio_tokens:
          type: number
          description: Аудио токены в промпте
          example: 0
        video_tokens:
          type: number
          description: Видео токены в промпте
          example: 0
    ServerToolUsePresenter:
      type: object
      properties:
        web_search_requests:
          type: number
          description: Количество вызовов веб-поиска
          example: 1
    GuardUsagePresenter:
      type: object
      properties:
        policy_version_id:
          type: string
          description: Версия политики защиты, по которой проверен запрос
          example: 3f2c1a9e-7b4d-4e8a-9c1f-2d5e6a7b8c9d
        action:
          type: string
          description: >-
            Что сделано с найденными данными: none — ничего не нашлось, audit —
            только записано, mask — заменено на [ТИП] до отправки модели
          enum:
            - none
            - audit
            - mask
            - pseudonymize
            - block
          example: mask
        entities:
          type: object
          description: Сколько данных каждого типа нашлось в запросе
          additionalProperties:
            type: number
          example:
            PHONE: 1
            EMAIL: 1
        layers:
          description: Какими способами проверялся запрос
          example:
            - regex
          type: array
          items:
            type: string
        degraded:
          type: boolean
          description: true — часть проверок была недоступна и запрос проверен не полностью
          example: false
      required:
        - policy_version_id
        - action
        - entities
        - layers
        - degraded
    ApiErrorMetadataPresenter:
      type: object
      properties:
        reason:
          type: string
          description: 'Машинная причина отказа: по ней можно ветвиться, не разбирая текст'
          example: noProvidersForModel
        raw:
          type: string
          description: Исходный текст ответа провайдера
          example: The parameter `duration` specified in the request is not valid
        provider_name:
          type: string
          description: Провайдер, вернувший ошибку
          example: alibaba
    ToolCallExtraContentDto:
      type: object
      properties:
        google:
          description: Метаданные вызова Google
          allOf:
            - $ref: '#/components/schemas/GoogleToolCallContentDto'
    ToolCallFunctionDto:
      type: object
      properties:
        name:
          type: string
          description: Имя вызываемой функции
          example: get_weather
        arguments:
          type: string
          description: JSON-строка с аргументами функции
          example: '{"location": "Moscow", "unit": "celsius"}'
      required:
        - name
        - arguments
    ToolCallPresenter:
      type: object
      properties:
        extra_content:
          description: Подпись вызова провайдера
          allOf:
            - $ref: '#/components/schemas/ToolCallExtraContentDto'
        id:
          type: string
          description: ID вызова функции
          example: call_abc123
        type:
          type: string
          description: Тип вызова
          example: function
        function:
          description: Информация о функции
          allOf:
            - $ref: '#/components/schemas/ToolCallFunctionPresenter'
      required:
        - id
        - type
        - function
    ReasoningDetailPresenter:
      type: object
      properties:
        index:
          type: number
          description: Индекс детали
          example: 0
        id:
          type: object
          description: Исходный ID reasoning
          example: rs_123
          nullable: true
        summary:
          type: string
          description: Краткое описание рассуждений
          example: Нужен результат инструмента
        signature:
          type: object
          description: Непрозрачная подпись рассуждений
          nullable: true
        type:
          type: string
          description: Тип reasoning детали
          example: reasoning.text
        text:
          type: string
          description: Текст reasoning (если type=reasoning.text)
          example: Анализирую запрос...
        data:
          type: string
          description: Зашифрованные данные (если type=reasoning.encrypted)
        format:
          type: string
          description: Формат данных
          example: google-gemini-v1
      required:
        - type
    ChatMessageTokenLogprobPresenter:
      type: object
      properties:
        token:
          type: string
          description: Токен
          example: hello
        logprob:
          type: number
          description: Log probability токена
          example: -0.5
        bytes:
          type: object
          description: Байты токена
          example:
            - 104
            - 101
            - 108
            - 108
            - 111
          nullable: true
        top_logprobs:
          description: Топ наиболее вероятных токенов с их вероятностями
          type: array
          items:
            $ref: '#/components/schemas/ChatMessageTokenLogprobTopItemPresenter'
      required:
        - token
        - logprob
        - bytes
        - top_logprobs
    GoogleToolCallContentDto:
      type: object
      properties:
        thought_signature:
          type: string
          description: Непрозрачная подпись вызова Google
          example: opaque-signature
    ToolCallFunctionPresenter:
      type: object
      properties:
        name:
          type: string
          description: Название функции
          example: get_weather
        arguments:
          type: string
          description: Аргументы функции в JSON формате
          example: '{"location": "Moscow"}'
      required:
        - name
        - arguments
    ChatMessageTokenLogprobTopItemPresenter:
      type: object
      properties:
        token:
          type: string
          description: Токен
          example: hello
        logprob:
          type: number
          description: Log probability токена
          example: -0.5
        bytes:
          type: object
          description: Байты токена
          example:
            - 104
            - 101
            - 108
            - 108
            - 111
          nullable: true
      required:
        - token
        - logprob
        - bytes
  securitySchemes:
    bearer:
      scheme: bearer
      bearerFormat: API Key
      type: http
      description: >-
        API ключ передаётся в заголовке: Authorization: Bearer
        <POLZA_AI_API_KEY>

````

This documentation is built and hosted on [Mintlify](https://mintlify.com), a developer documentation platform.