#!/data/data/com.termux/files/usr/bin/bash
# screening de variantes I-12: 5 arranques en frio por variante.
set -u
RT="$PREFIX/tmp/rt-dex"
DISTRO="proot-distro login ubuntu-gnome --shared-tmp --"
N=5
run_series() {
  tag=$1
  : > "$RT/boot-series-$tag.csv"
  for n in $(seq 1 $N); do
    bash "$PREFIX/bin/gnome49-stop" >/dev/null 2>&1
    sleep 1
    T0=$(date +%s)
    OUT=$(SUBSTRATE_NO_SUPERVISOR=1 bash "$PREFIX/bin/gnome49" 2>&1)
    T1=$(date +%s)
    dur=$((T1-T0))
    if echo "$OUT" | grep -q "OK: GNOME Shell 49"; then R=OK; else R=FALLO; fi
    echo "$tag,$n,$dur,$R" >> "$RT/boot-series-$tag.csv"
    echo "[$tag] boot $n -> $R (${dur}s)"
  done
}

apply() { $DISTRO bash -c "$1"; }

# guardar copia base
$DISTRO bash -c 'cp -f /etc/profile.d/zz-adreno-gpu.sh /tmp/zz-adreno-gpu.sh.pre-screening'
echo "BASE=$(date +%T)"
run_series base

# V1: TU_DEBUG=noubwc
$DISTRO bash -c 'cp -f /tmp/zz-adreno-gpu.sh.pre-screening /etc/profile.d/zz-adreno-gpu.sh; echo "export TU_DEBUG=noubwc" >> /etc/profile.d/zz-adreno-gpu.sh'
echo "V1=$(date +%T)"; run_series v1-noubwc

# V2: TU_DEBUG=noltoc
$DISTRO bash -c 'cp -f /tmp/zz-adreno-gpu.sh.pre-screening /etc/profile.d/zz-adreno-gpu.sh; echo "export TU_DEBUG=noltoc" >> /etc/profile.d/zz-adreno-gpu.sh'
echo "V2=$(date +%T)"; run_series v2-noltoc

# V3: WSI fifo
$DISTRO bash -c 'cp -f /tmp/zz-adreno-gpu.sh.pre-screening /etc/profile.d/zz-adreno-gpu.sh; sed -i "s/MESA_VK_WSI_PRESENT_MODE=immediate/MESA_VK_WSI_PRESENT_MODE=fifo/" /etc/profile.d/zz-adreno-gpu.sh'
echo "V3=$(date +%T)"; run_series v3-fifo

# restaurar base (ganadora actual) por defecto
$DISTRO bash -c 'cp -f /tmp/zz-adreno-gpu.sh.pre-screening /etc/profile.d/zz-adreno-gpu.sh'
echo "DONE=$(date +%T)"
