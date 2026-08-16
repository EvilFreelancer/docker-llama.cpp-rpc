FROM ubuntu:24.04 AS builder
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
 && apt install -fyq bash wget git cmake make g++ curl libcurl4-openssl-dev \
 && apt clean

# Clone repo
RUN set -xe \
 && git clone --branch "$LLAMACPP_VERSION" --depth 1 "$LLAMACPP_REPO"

# Build binaries
WORKDIR /app/llama.cpp
# On arm64 the image is built under QEMU emulation, where "native" CPU
# detection sees the QEMU CPU model with extensions (SVE and friends) that
# real boards may lack, so the resulting binaries crash with an illegal
# instruction. GGML_NATIVE=OFF keeps the arm64 build on the portable
# armv8-a baseline. The amd64 build is left as is.
ARG TARGETARCH
RUN set -xe \
 && if [ "$TARGETARCH" = "arm64" ]; then EXTRA_FLAGS="-DGGML_NATIVE=OFF"; else EXTRA_FLAGS=""; fi \
 && cmake -B build -DGGML_RPC=ON -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON $EXTRA_FLAGS \
 && cmake --build build --config Release -j$(nproc)

# Stage shared libraries preserving symlink structure: newer llama.cpp
# ships versioned SONAMEs (libggml.so.0 -> libggml.so.0.x.y), and a plain
# COPY of *.so would dereference symlinks and lose the SONAME names the
# binaries actually load.
RUN set -xe \
 && mkdir -pv /app/libs \
 && cp -av build/bin/*.so* /app/libs/


FROM ubuntu:24.04
WORKDIR /app

# Install basic dependencies
RUN set -xe \
 && apt update -q \
 && apt install -fyq libgomp1 curl \
 && apt clean

# Create folders
RUN set -xe \
 && mkdir -pv /app/models

# Copy compiled libraries into the arch-native libdir: the same
# /usr/lib/x86_64-linux-gnu as always on amd64, its aarch64 equivalent
# on arm64 (the linker does not search a foreign-arch libdir).
ARG TARGETARCH
COPY --from=builder /app/libs/ /tmp/libs/
RUN set -xe \
 && case "$TARGETARCH" in \
      arm64) libdir=/usr/lib/aarch64-linux-gnu ;; \
      *)     libdir=/usr/lib/x86_64-linux-gnu ;; \
    esac \
 && mv /tmp/libs/* "$libdir"/ \
 && rmdir /tmp/libs

# Copy compiled tools under whatever names the build produced.
# llama.cpp b9824 renamed rpc-server to ggml-rpc-server (#25045), so the
# glob matches either name and the old one is kept as a symlink.
COPY --from=builder /app/llama.cpp/build/bin/*rpc-server .
RUN set -xe \
 && if [ -e ggml-rpc-server ] && [ ! -e rpc-server ]; then ln -s ggml-rpc-server rpc-server; fi
COPY --from=builder /app/llama.cpp/build/bin/llama-cli .
COPY --from=builder /app/llama.cpp/build/bin/llama-embedding .
COPY --from=builder /app/llama.cpp/build/bin/llama-server .

# Init entrypoint
ADD entrypoint.sh .
ENTRYPOINT ["/app/entrypoint.sh"]
