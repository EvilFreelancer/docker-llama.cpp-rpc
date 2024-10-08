FROM ubuntu:22.04 AS builder
WORKDIR /app

ARG LLAMACPP_REPO="https://github.com/ggerganov/llama.cpp.git"
# It may be name of branch, tag or commit hash
ARG LLAMACPP_VERSION="master"

# To get latest tag use this:
# git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' \
#    "https://github.com/ggerganov/llama.cpp.git" 'b*' | \
#    tail --lines=1 | cut --delimiter='/' --fields=3
# For details see here: https://stackoverflow.com/questions/8932389/git-shallow-clone-to-specific-tag)

# Install dependencies
RUN set -xe \
 && apt update -q \
 && apt install -fyq bash wget git make g++ \
 && apt clean

# Clone repo
RUN set -xe \
 && git clone --branch "$LLAMACPP_VERSION" --depth 1 "$LLAMACPP_REPO"

# Build binaries
WORKDIR /app/llama.cpp
RUN set -xe \
 && GGML_RPC=ON make -j$(nproc) llama-server llama-cli llama-embedding rpc-server libggml.so libllama.so



FROM ubuntu:22.04
WORKDIR /app

# Install basic dependencies
RUN set -xe \
 && apt update -q \
 && apt install -fyq libgomp1 \
 && apt clean

# Create folders
RUN set -xe \
 && mkdir -pv /app/models

# Copy compiled tools
COPY --from=builder /app/llama.cpp/libllama.so /usr/lib/x86_64-linux-gnu
COPY --from=builder /app/llama.cpp/libggml.so /usr/lib/x86_64-linux-gnu
COPY --from=builder /app/llama.cpp/rpc-server .
COPY --from=builder /app/llama.cpp/llama-cli .
COPY --from=builder /app/llama.cpp/llama-embedding .
COPY --from=builder /app/llama.cpp/llama-server .

# Init entrypoint
ADD entrypoint.sh .
ENTRYPOINT ["/app/entrypoint.sh"]
