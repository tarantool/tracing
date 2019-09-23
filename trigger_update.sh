#!/bin/bash

body=$(cat <<EOF
{
    "update_key": "${TRACING_UPDATE_KEY}"
}
EOF
)

curl -X POST -H "Content-Type: application/json" --data "${body}" "${TRIGGER_URL}"