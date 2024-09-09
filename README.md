# llama.cpp RPC-server in Docker

Данный проект основан на [llama.cpp](https://github.com/ggerganov/llama.cpp) и компилирует только RPC-сервер, а так же
вспомогательные утилиты работающие в режиме RPC-клиента необходимые для реализации распределённого инференса
конвертированных в GGUF формат Больших Языковых Моделей (БЯМ) и Эмбеддинговых Моделей.

**Русский** | 中文 | English

## Обзор

В общем виде схема приложения с использованием RPC-сервера имеет следующий вид:

![schema](./assets/schema.png)

Вместо `llama-server` можно использовать `llama-cli` или `llama-embedding`, они идут в стандартной поставке контейнера.

## Пример docker-compose.yml

В данном примере происходит запуск `llama-server` (контейнер `main`) и инициализация модели `TinyLlama-1.1B-q4_0.gguf`,
которая расположена в директории `./models` на одном уровне с `docker-compose.yml`. Директория `./models` в свою очередь
монтируется внутрь контейнера `main` и доступна по пути `/app/models`.

```yaml
version: "3.9"

services:

  main:
    image: evilfreelancer/llama.cpp-rpc:latest
    restart: unless-stopped
    volumes:
      - ./models:/app/models
    environment:
      # Режим работы (RPC-клиент в формате API-сервера)
      APP_MODE: server
      # Путь до весов модели внутри контейнера
      APP_MODEL: /app/models/TinyLlama-1.1B-q4_0.gguf
      # Адреса RPC серверов с которыми будет взаимодействовать клиент
      APP_RPC_BACKENDS: backend-cuda:50052,backend-cpu:50052

  backend-cpu:
    image: evilfreelancer/llama.cpp-rpc:latest
    restart: unless-stopped
    environment:
      # Режим работы (RPC-сервер)
      APP_MODE: backend
      # Количество доступной RPC-серверу оперативной памяти (в Мегабайтах)
      APP_MEM: 2048

  backend-cuda:
    image: evilfreelancer/llama.cpp-rpc:latest-cuda
    restart: "unless-stopped"
    environment:
      # Режим работы (RPC-сервер)
      APP_MODE: backend
      # Количество доступной RPC-серверу оперативной памяти (в Мегабайтах)
      APP_MEM: 1024
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [ gpu ]
```

Полный пример в [docker-compose.dist.yml](./docker-compose.dist.yml).

В результате чего у нас получается следующего вида схема:

![schema-example](./assets/schema-example.png)

## Переменные окружения

| Имя                | Дефолт                                         | Описание                                                                                                    |
|--------------------|------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| APP_MODE           | backend                                        | Режим работы контейнера, доступные варианты: `server`, `backend` и `none`                                   |
| APP_BIND           | 0.0.0.0                                        | Интерфейс на который происходит биндинг                                                                     |
| APP_PORT           | у `server` это `8080`, у `backend` это `50052` | Номер порта на котором запускается сервер                                                                   |
| APP_MEM            | 1024                                           | Количество оперативной памяти доступной клиента, в режиме CUDA это количество оперативной памяти видеокарты | 
| APP_RPC_BACKENDS   | backend-cuda:50052,backend-cpu:50052           | Адреса бэкендов к которым будет пытаться подключиться контейнер в режиме `server`                           |
| APP_MODEL          | /app/models/TinyLlama-1.1B-q4_0.gguf           | Путь к весам модели внутри контейнера                                                                       | 
| APP_REPEAT_PENALTY | 1.0                                            | Пенальти повторов                                                                                           |
| APP_GPU_LAYERS     | 99                                             | Количество слоёв выгружаемых на бэкенд                                                                      |

## Ручная сборка через Docker

Сборка контейнеров в режиме CPU-only:

```shell
docker build ./llama.cpp/
```

Сборка контейнера под CUDA:

```shell
docker build ./llama.cpp/ --file ./llama.cpp/Dockerfile.cuda
```

При помощи аргумента сборки `LLAMACPP_VERSION` можно указать версию тега, название ветки или хеш коммиат из которого
требуется выполнить сборку контейнера, например:

```shell
# Собрать контейнер из тега https://github.com/ggerganov/llama.cpp/releases/tag/b3700
docker build ./llama.cpp/ --build-arg LLAMACPP_VERSION=b3700

# Собрать контейнер из ветки master
docker build ./llama.cpp/ --build-arg LLAMACPP_VERSION=master
```
