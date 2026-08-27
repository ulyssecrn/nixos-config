#!/usr/bin/env bash
# Probe how much context a llama.cpp config actually allocates on genghis's 3090.
#
# WHY THIS EXISTS: the VRAM budget on a 24 GB card is tight enough that the only
# honest way to pick `ctx-size` / `cache-type-*` is to boot it and look. Arithmetic
# gets you a candidate; this tells you whether it fits.
#
# It refuses to report a number unless the model is genuinely on the GPU. A driver
# version skew (rebuild without reboot) makes llama.cpp fall back to CPU *silently*
# — it boots, answers correctly, and every VRAM figure is meaningless. That cost a
# whole test round on 2026-08-27. See the CUDA notes in AGENTS.md.
#
# Usage: try-ctx.sh <ctx> [ubatch] [kv-type] [model-path]
#   try-ctx.sh 200704                 # q8_0 KV, ub 1024, UD-IQ4_XS
#   try-ctx.sh 262144 512 q5_1
set -u

CTX="${1:?usage: try-ctx.sh <ctx> [ubatch] [kv-type] [model-path]}"
UB="${2:-1024}"
KV="${3:-q8_0}"
MODEL="${4:-/models/Qwen3.8-27B-UD-IQ4_XS.gguf}"
PORT="${PORT:-8081}"
LOGDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$LOGDIR/try-ctx-$CTX-$KV.log"

# Resolve the binary from the running unit so this doesn't rot on every rebuild.
BIN=$(systemctl show llama-cpp -p ExecStart --value 2>/dev/null \
      | grep -o '/nix/store/[^ ;]*/bin/llama-server' | head -1)
[ -x "${BIN:-}" ] || BIN=$(command -v llama-server || true)
[ -x "${BIN:-}" ] || { echo "no llama-server binary found"; exit 1; }
[ -f "$MODEL" ]   || { echo "missing model: $MODEL"; exit 1; }

# ---- preflight -------------------------------------------------------------
if ! nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits >/dev/null 2>&1; then
  echo "ABORT: nvidia-smi not working - any result would be a CPU-fallback artifact."
  nvidia-smi 2>&1 | head -2
  if [ "$(readlink -f /run/booted-system)" != "$(readlink -f /run/current-system)" ]; then
    echo "cause: rebuild since boot (booted != current system) -> REBOOT required"
  fi
  exit 1
fi
if systemctl is-active --quiet llama-cpp; then
  echo "ABORT: llama-cpp is running and holds the VRAM. Run: sudo systemctl stop llama-cpp"
  exit 1
fi
VRAM_BEFORE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
echo "GPU ok (${VRAM_BEFORE} MiB in use)"
echo "binary: $BIN"

"$BIN" --host 127.0.0.1 --port "$PORT" -m "$MODEL" \
  -c "$CTX" -b 4096 -ub "$UB" -ngl 99 -fa on \
  --cache-type-k "$KV" --cache-type-v "$KV" \
  -np 1 --spec-type draft-mtp --spec-draft-n-max 2 \
  --jinja --reasoning off --reasoning-format deepseek \
  --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.0 --repeat-penalty 1.0 \
  > "$LOG" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null; wait $PID 2>/dev/null' EXIT

printf "ctx=%s ub=%s kv=%s booting" "$CTX" "$UB" "$KV"
for _ in $(seq 1 180); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  kill -0 $PID 2>/dev/null || { echo " DIED"; tail -15 "$LOG"; exit 1; }
  printf "."; sleep 2
done
echo " up"

# ---- refuse to report a CPU run --------------------------------------------
# Detect by VRAM delta, NOT by log grep: llama.cpp b10273 prints no per-buffer
# CUDA lines at default verbosity, so grepping for them false-positives on a
# perfectly good GPU run (learned 2026-08-27).
VRAM_AFTER=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
DELTA=$(( VRAM_AFTER - VRAM_BEFORE ))
if [ "$DELTA" -lt 5000 ]; then
  echo "ABORT: VRAM only grew ${DELTA} MiB - model is on CPU, result meaningless."
  grep -iE "cuda|backend|device|error" "$LOG" | head -5
  exit 1
fi
echo "VRAM delta: +${DELTA} MiB (weights are on the GPU)"

USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
awk -v u="$USED" 'BEGIN{printf "VRAM: %s MiB used / 24576  ->  %.2f GiB free\n", u, (24576-u)/1024}'
grep -iE "KV self|n_ctx +=|n_ctx_slot" "$LOG" | head -4

echo "--- functional probe (decode should be >40 tok/s on GPU) ---"
curl -s --max-time 120 "http://127.0.0.1:$PORT/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Reply with exactly: OK"}],"max_tokens":10}' >/dev/null
grep "print_timing" "$LOG" | tail -3
echo "log: $LOG"
