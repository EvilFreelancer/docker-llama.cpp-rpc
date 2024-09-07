#!/bin/bash

cd "$(dirname "$0")"

[ "x$MODE" = "x" ] && export MODE="backend"
[ "x$APP_BIND" = "x" ] && export APP_BIND="0.0.0.0"
[ "x$APP_MEM" = "x" ] && export APP_MEM="1024"
[ "x$APP_RPC" = "x" ] && export APP_RPC_BACKENDS="backend-cuda:50052,backend-cpu:50052"
[ "x$APP_MODEL" = "x" ] && export APP_MODEL="/app/models/TinyLlama-1.1B-F16.gguf"
[ "x$APP_REPEAT_PENALTY" = "x" ] && export APP_REPEAT_PENALTY="1.0"
[ "x$APP_GPU_LAYERS" = "x" ] && export APP_GPU_LAYERS="99"

# Construct the command with the options
if [ "$MODE" = "backend" ]; then
    [ "x$APP_PORT" = "x" ] && export APP_PORT="50052"
    # RPC backend
    CMD="/app/rpc-server"
    CMD+=" --host $APP_BIND"
    CMD+=" --port $APP_PORT"
    CMD+=" --mem $APP_MEM"
elif [ "$MODE" = "server" ]; then
    [ "x$APP_PORT" = "x" ] && export APP_PORT="8080"
    # API server connected to multipla backends
    CMD="/app/llama-server"
    CMD+=" --host $APP_BIND"
    CMD+=" --port $APP_PORT"
    CMD+=" --model $APP_MODEL"
    CMD+=" --repeat-penalty $APP_REPEAT_PENALTY"
    CMD+=" --rpc $APP_RPC_BACKENDS"
    CMD+=" --gpu-layers $APP_GPU_LAYERS"
elif [ "$MODE" = "none" ]; then
    # For cases when you want to use /app/llama-cli
    echo "MODE is set to none. Sleeping indefinitely."
    CMD="sleep inf"
else
    echo "Invalid MODE specified: $MODE"
    exit 1
fi

# Execute the command
echo && echo "Executing command: $CMD" && echo
exec $CMD
exit 0
