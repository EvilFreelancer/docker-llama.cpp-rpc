#!/bin/bash

set -xe

curl \
    --request POST \
    --url http://localhost:8080/embeddings \
    --header "Content-Type: application/json" \
    --data '{"content": "Building a website can be done in 10 simple steps:"}'
