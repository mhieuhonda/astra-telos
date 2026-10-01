#!/bin/bash
# Astra Telos - Script khoi dong server tren may nay
export PATH="/opt/flutter/bin:$PATH"
export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
cd "$(dirname "$0")/server"
ASTRA_PORT=${ASTRA_PORT:-8085} dart run bin/server.dart
