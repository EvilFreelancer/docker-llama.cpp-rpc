# llama.cpp RPC服务器在Docker中

该项目基于[llama.cpp](https://github.com/ggerganov/llama.cpp)
，仅编译RPC服务器以及以[RPC](https://github.com/ggerganov/llama.cpp/tree/master/examples/rpc)
客户端模式运行的辅助工具，这些工具对于分布式推理转化为GGUF格式的大型语言模型（LLMs）和嵌入模型是必需的。

[Русский](./README.md) | **中文** | [English](./README.en.md)

## 概述

使用RPC服务器的应用程序的通用架构如下所示：

![schema](./assets/schema.png)

除了`llama-server`，您还可以使用`llama-cli`或`llama-embedding`，它们都包含在标准的容器包中。

Docker镜像支持以下架构：

* 仅CPU - amd64, arm64, arm/v7
* CUDA - amd64

不幸的是，CUDA在arm64上的构建由于错误而失败，因此它们暂时被禁用。

## 环境变量

| 名称                 | 默认值                                   | 描述                                     |
|--------------------|---------------------------------------|----------------------------------------|
| APP_MODE           | backend                               | 容器的操作模式，可用选项：`server`，`backend`和`none` |
| APP_BIND           | 0.0.0.0                               | 绑定到的接口                                 |
| APP_PORT           | 对于`server`是`8080`，对于`backend`是`50052` | 服务器运行的端口号                              |
| APP_MEM            | 1024                                  | 客户端可用的内存量；在CUDA模式下，这是显存量               | 
| APP_RPC_BACKENDS   | backend-cuda:50052,backend-cpu:50052  | 以逗号分隔的后端地址列表，容器将在server模式下尝试连接这些地址     |
| APP_MODEL          | /app/models/TinyLlama-1.1B-q4_0.gguf  | 容器内的模型权重路径                             | 
| APP_REPEAT_PENALTY | 1.0                                   | 重复惩罚                                   |
| APP_GPU_LAYERS     | 99                                    | 卸载到后端的层数                               |

## docker-compose.yml示例

在此示例中，`llama-server`（容器`main`）启动并初始化[TinyLlama-1.1B-q4_0.gguf]模型，该模型预先下载到与`docker-compose.yml`
位于同一级的`./models`目录中。然后将`./models`目录挂载到`main`容器内部，并在路径`/app/models`下可用。

```yaml
version: "3.9"

services:

  main:
    image: evilfreelancer/llama.cpp-rpc:latest
    restart: unless-stopped
    volumes:
      - ./models:/app/models
    environment:
      # 操作模式（API服务器格式的RPC客户端）
      APP_MODE: server
      # 容器内部预先加载的模型权重路径
      APP_MODEL: /app/models/TinyLlama-1.1B-q4_0.gguf
      # 客户端将与之交互的RPC服务器地址
      APP_RPC_BACKENDS: backend-cuda:50052,backend-cpu:50052
    ports:
      - "127.0.0.1:8080:8080"

  backend-cpu:
    image: evilfreelancer/llama.cpp-rpc:latest
    restart: unless-stopped
    environment:
      # 操作模式（RPC服务器）
      APP_MODE: backend
      # RPC服务器可用的系统RAM大小（以MB为单位）
      APP_MEM: 2048

  backend-cuda:
    image: evilfreelancer/llama.cpp-rpc:latest-cuda
    restart: "unless-stopped"
    environment:
      # 操作模式（RPC服务器）
      APP_MODE: backend
      # RPC服务器可用的显存大小（以MB为单位）
      APP_MEM: 1024
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [ gpu ]
```

完整示例见[docker-compose.dist.yml](./docker-compose.dist.yml)。

结果我们得到如下图所示的架构：

![schema-example](./assets/schema-example.png)

启动后，可以发送如下的HTTP请求：

```shell
curl \
    --request POST \
    --url http://localhost:8080/completion \
    --header "Content-Type: application/json" \
    --data '{"prompt": "Building a website can be done in 10 simple steps:"}'
```

## 手动通过Docker构建

仅CPU模式下的容器构建：

```shell
docker build ./llama.cpp/
```

针对CUDA的容器构建：

```shell
docker build ./llama.cpp/ --file ./llama.cpp/Dockerfile.cuda
```

通过构建参数LLAMACPP_VERSION，可以指定标记版本、分支名称或提交哈希值以从中构建容器。默认情况下，容器中指定的是master分支。

```shell
# 从标记构建容器 https://github.com/ggerganov/llama.cpp/releases/tag/b3700
docker build ./llama.cpp/ --build-arg LLAMACPP_VERSION=b3700
```

```shell
# 从master分支构建容器
docker build ./llama.cpp/ --build-arg LLAMACPP_VERSION=master
# 或者简单地
docker build ./llama.cpp/
```

## 使用Docker Compose手动构建

一个执行显式标记指定的镜像构建的docker-compose.yml示例。

```yaml
version: "3.9"

services:

  main:
    restart: "unless-stopped"
    build:
      context: ./llama.cpp
      args:
        - LLAMACPP_VERSION=b3700
    volumes:
      - ./models:/app/models
    environment:
      APP_MODE: none
    ports:
      - "8080:8080"

  backend:
    restart: "unless-stopped"
    build:
      context: ./llama.cpp
      args:
        - LLAMACPP_VERSION=b3700
    environment:
      APP_MODE: backend
    ports:
      - "50052:50052"
```

## 链接

- https://github.com/ggerganov/ggml/pull/761
- https://github.com/ggerganov/llama.cpp/issues/7293
- https://github.com/ggerganov/llama.cpp/pull/6829
- https://github.com/ggerganov/llama.cpp/tree/master/examples/rpc
- https://github.com/mudler/LocalAI/commit/fdb45153fed10d8a2c775633e952fdf02de60461
- https://github.com/mudler/LocalAI/pull/2324
- https://github.com/ollama/ollama/issues/4643

## 引用

```text
[Pavel Rykov]. (2024). llama.cpp RPC-server in Docker. GitHub. https://github.com/EvilFreelancer/docker-llama.cpp-rpc
```

```text
@misc{pavelrykov2024llamacpprpc,
  author = {Pavel Rykov},
  title  = {llama.cpp RPC-server in Docker},
  year   = {2024},
  url    = {https://github.com/EvilFreelancer/docker-llama.cpp-rpc}
}
```
