# Dockerized llama.cpp RPC-server

```shell
docker buildx build \
  --builder=my_builder --push \
  --platform=linux/amd64,linux/arm64,linux/arm/v7 \
  --build-arg LLAMACPP_VERSION=b3600 \
  --tag=evilfreelancer/llama.cpp-rpc:b3600 \
  ./llama.cpp/
```

```shell
docker buildx build \
  --file ./llama.cpp/Dockerfile.cuda \
  --builder=my_builder --push \
  --platform=linux/amd64 \
  --build-arg LLAMACPP_VERSION=b3600 \
  --tag=evilfreelancer/llama.cpp-rpc:b3600-cuda \
  ./llama.cpp/
```
