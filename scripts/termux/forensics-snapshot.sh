#!/data/data/com.termux/files/usr/bin/bash
# forensics-snapshot.sh - guarda evidencia de una muerte/fallo de la sesion GNOME 49.
# Uso: forensics-snapshot.sh [etiqueta]
set -u
RT="$PREFIX/tmp/rt-dex"
TAG="${1:-DEATH}"
D="$RT/forensics/${TAG}-$(date +%s)"
mkdir -p "$D"

{
  echo "== fecha: $(date -Is)"
  echo "== shell49.pid: $(cat "$RT/shell49.pid" 2>/dev/null || echo '-')"
  echo "== supervisor: $(cat "$RT/supervisor49.pid" 2>/dev/null || echo '-')"
} > "$D/summary.txt" 2>&1

tail -40 "$RT/watcher.log"  > "$D/watcher-tail.log" 2>/dev/null || true
tail -40 "$RT/shell49.log"  > "$D/shell49-tail.log" 2>/dev/null || true
tail -40 "$RT/last-gnome49.log" > "$D/last-gnome49-tail.log" 2>/dev/null || true

{
  for f in gpufaults gpufault_procs ft_policy ft_long_ib_detect ft_hang_intr_status \
           gpu_busy_percentage gpu_model; do
    printf '%-22s = ' "$f"
    cat "/sys/class/kgsl/kgsl-3d0/$f" 2>/dev/null || echo '?'
  done
} > "$D/kgsl.txt" 2>&1

ps -eo pid,ppid,stat,args > "$D/ps.txt" 2>&1 || true

if command -v adb >/dev/null 2>&1; then
  timeout 10 adb -s 127.0.0.1:5555 logcat -d -b all -v time 2>/dev/null | tail -600 > "$D/logcat-all-tail.log" || true
  timeout 10 adb -s 127.0.0.1:5555 shell cat /proc/meminfo 2>/dev/null > "$D/meminfo.txt" || true
  timeout 15 adb -s 127.0.0.1:5555 shell dumpsys procstats --hours 1 2>/dev/null > "$D/procstats.txt" || true
  timeout 10 adb -s 127.0.0.1:5555 shell dumpsys activity exit-info com.termux 2>/dev/null > "$D/exit-info-termux.txt" || true
fi

echo "$D"
