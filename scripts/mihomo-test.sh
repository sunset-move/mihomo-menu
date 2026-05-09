#!/usr/bin/env bash
set -euo pipefail

curl -I --proxy http://127.0.0.1:7890 --max-time 20 https://www.google.com/generate_204
