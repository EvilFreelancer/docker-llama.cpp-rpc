#!/bin/bash

cd "$(dirname "$0")"

# If arguments passed to the script — treat them as custom command
if [ "$#" -gt 0 ]; then
    echo && echo "Custom CMD detected, executing: $*" && echo
    exec "$@"
fi

# Default env setup
[ "x$APP_MODE" = "x" ] && export APP_MODE="backend"
[ "x$APP_BIND" = "x" ] && export APP_BIND="0.0.0.0"
[ "x$APP_MEM" = "x" ] && export APP_MEM="1024"
[ "x$APP_MODEL" = "x" ] && export APP_MODEL="/app/models/TinyLlama-1.1B-q4_0.gguf"
[ "x$APP_REPEAT_PENALTY" = "x" ] && export APP_REPEAT_PENALTY="1.0"
[ "x$APP_GPU_LAYERS" = "x" ] && export APP_GPU_LAYERS="99"
[ "x$APP_THREADS" = "x" ] && export APP_THREADS="16"
[ "x$APP_DEVICE" = "x" ] && unset APP_DEVICE
[ "x$APP_CACHE" = "x" ] && export APP_CACHE="false"
[ "x$APP_EMBEDDING" = "x" ] && export APP_EMBEDDING="false"

# Construct the command with the options
if [ "$APP_MODE" = "backend" ]; then
    [ "x$APP_PORT" = "x" ] && export APP_PORT="50052"
    # RPC backend
    CMD="/app/rpc-server"
    CMD+=" --host $APP_BIND"
    CMD+=" --port $APP_PORT"
    # Upstream removed --mem (rpc-server reports actual free memory itself,
    # ggml-org/llama.cpp#16616); pass the flag only to binaries that still
    # support it, otherwise the server dies with "unknown argument" and the
    # container ends up in a restart loop.
    if /app/rpc-server --help 2>&1 | grep -q -- '--mem'; then
        CMD+=" --mem $APP_MEM"
    fi
    CMD+=" --threads $APP_THREADS"
    [ -n "$APP_DEVICE" ] && CMD+=" --device $APP_DEVICE"
    [ "$APP_CACHE" = "true" ] && CMD+=" --cache"
elif [ "$APP_MODE" = "server" ]; then
    [ "x$APP_PORT" = "x" ] && export APP_PORT="8080"
    # API server connected to multipla backends
    CMD="/app/llama-server"
    CMD+=" --host $APP_BIND"
    CMD+=" --port $APP_PORT"
    CMD+=" --model $APP_MODEL"
    CMD+=" --repeat-penalty $APP_REPEAT_PENALTY"
    CMD+=" --gpu-layers $APP_GPU_LAYERS"
    [ -n "$APP_RPC_BACKENDS" ] && CMD+=" --rpc $APP_RPC_BACKENDS"
    [ "$APP_EMBEDDING" = "true" ] && CMD+=" --embedding"
elif [ "$APP_MODE" = "none" ]; then
    # For cases when you want to use /app/llama-cli
    echo "APP_MODE is set to none. Sleeping indefinitely."
    CMD="sleep inf"
else
    echo "Invalid APP_MODE specified: $APP_MODE"
    exit 1
fi

# Execute the command
echo && echo "Executing command: $CMD" && echo
exec $CMD
exit 0
