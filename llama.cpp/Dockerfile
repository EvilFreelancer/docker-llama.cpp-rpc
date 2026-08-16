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
# GGML_NATIVE=OFF on every platform: images are compiled on CI runners
# whose ISA (AVX512, QEMU-emulated SVE on arm64) user machines may lack,
# and native-tuned binaries die there with an illegal instruction and no
# log output (issue #2). On amd64 performance is restored by building all
# CPU backend variants as dlopen modules (GGML_BACKEND_DL +
# GGML_CPU_ALL_VARIANTS, same as upstream .devops images): the best one
# for the host CPU is picked at runtime. On arm64 that is skipped for now
# (QEMU-emulated compilation of every variant is too slow), so the build
# stays on the portable armv8-a baseline.
ARG TARGETARCH
RUN set -xe \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      EXTRA_FLAGS="-DGGML_NATIVE=OFF"; \
    else \
      EXTRA_FLAGS="-DGGML_NATIVE=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON"; \
    fi \
 && cmake -B build -DGGML_RPC=ON -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON $EXTRA_FLAGS \
 && if cmake --build build --target help | grep -q ggml-rpc-server; then RPC_TARGET=ggml-rpc-server; else RPC_TARGET=rpc-server; fi \
 && BACKEND_TARGETS=$(cmake --build build --target help | grep -oE 'ggml-[a-zA-Z0-9._-]+' | sort -u | tr '\n' ' ') \
 && cmake --build build --config Release -j$(nproc) --target llama-server llama-cli llama-embedding "$RPC_TARGET" $BACKEND_TARGETS

# Stage shared libraries preserving symlink structure: newer llama.cpp
# ships versioned SONAMEs (libggml.so.0 -> libggml.so.0.x.y), and a plain
# COPY of *.so would dereference symlinks and lose the SONAME names the
# binaries actually load. find covers dlopen backend modules regardless
# of the directory the build placed them in.
RUN set -xe \
 && mkdir -pv /app/libs \
 && find build -name "*.so*" -exec cp -Pv {} /app/libs/ \;


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
 && rmdir /tmp/libs \
 # amd64 builds ship backends as dlopen modules (GGML_BACKEND_DL); ggml
 # scans the executable directory rather than the linker path, so the
 # modules must live in /app next to the binaries. arm64 links backends
 # as ordinary shared libraries, those stay in the libdir.
 && if [ "$TARGETARCH" != "arm64" ]; then \
      find "$libdir" -maxdepth 1 \( -name 'libggml-cpu-*.so*' -o -name 'libggml-rpc*.so*' \) -exec mv -v {} /app/ \; ; \
    fi

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
