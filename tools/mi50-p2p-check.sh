#!/usr/bin/env bash
# mi50-p2p-check.sh — "is PCIe P2P working on this MI50 box, and if not, which gate blocks it?"
#
# A single script, run as a normal user (no sudo needed except for journalctl on some boxes).
# READ-ONLY by default. It never reboots, never flashes, never restarts anything.
#
# Usage:
#   ./mi50-p2p-check.sh                # all read-only gates + verdict
#   ./mi50-p2p-check.sh --deep         # + real verified GPU-to-GPU copy (see below)
#   ./mi50-p2p-check.sh --deep --pair 0,2 --size 4m
#
# --deep compiles a small HIP program and does a verified hipMemcpyPeer copy
# (DMA only, no kernel peer-reads) of --size bytes (default 64 KiB, max 16 MiB)
# in BOTH directions, re-seeding the source pattern before each direction.
# It picks the two least-busy GPUs automatically unless --pair is given.
# It does not touch services, clocks, host memory, or other processes' buffers.
#
# Background (what each gate means) — from DByte308/mi50-p2p-fixes + the gfx906-hub P2P runbook:
#   Gate 2  VBIOS ROM must be a P2P/ReBAR-capable 32 GB ROM.
#   Gate 3  gfx906 DMA masks at 44 bits (16 TiB): GPU BARs ABOVE that = no P2P,
#           or "enabled but corrupt" if you force the mask up instead.
#   Gate 4  Kernel must be built with CONFIG_PCI_P2PDMA (distro kernels often lack it;
#           without it every "P2P" runs on a degraded host-staged fallback).
#   Gate 5  Kernel's own verdict in the log ("PCIe P2P ... not supported by the chipset").
#   Gate 9  Driver link matrix (rocm-smi --showtopoaccess) must be True all round.
#
# Credits:
#   Brad Harrison (https://github.com/bradgharrison) — the original P2P fix
#     (https://pastebin.com/g9hFc9WZ) and this tool
#   DByte308 (https://github.com/DByte308) — mi50-p2p-fixes, the three-gate story it encodes
#
# Sources:
#   https://github.com/DByte308/mi50-p2p-fixes (X99 three-gate story + PEX case study)
#   gfx906-hub README "P2P Guide" (hermesbradgharrison/gfx906-hub)

set -u
LC_ALL=C; export LC_ALL

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_BAD=$'\033[31m'; C_WARN=$'\033[33m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'; C_B=$'\033[1m'
else
  C_OK=""; C_BAD=""; C_WARN=""; C_DIM=""; C_RST=""; C_B=""
fi

DEEP=0; PAIR=""; SIZE_KIB=64
while [ $# -gt 0 ]; do
  case "$1" in
    --deep) DEEP=1 ;;
    --pair) shift; PAIR="${1:-}" ;;
    --size) shift; s="${1:-64k}"
      case "$s" in
        *k|*K) SIZE_KIB="${s%[kK]}" ;;
        *m|*M) SIZE_KIB=$(( ${s%[mM]} * 1024 )) ;;
        *g|*G) SIZE_KIB=$(( ${s%[gG]} * 1024 * 1024 )) ;;
        *)     SIZE_KIB="$s" ;;
      esac ;;
    -h|--help) grep -E '^# ?[A-Za-z( ].*' "$0" | sed 's/^# //' | head -22; exit 0 ;;
    *) echo "unknown arg: $1 (try --help)"; exit 2 ;;
  esac
  shift
done
SIZE_KIB=$(( ${SIZE_KIB:-64} + 0 ))
[ "$SIZE_KIB" -le 0 ] && SIZE_KIB=64
[ "$SIZE_KIB" -gt 16384 ] && SIZE_KIB=16384
SIZE_BYTES=$(( SIZE_KIB * 1024 ))

FAILS=0; WARNS=0
ok()   { printf '%s[ ok ]%s %s\n' "$C_OK" "$C_RST" "$1"; }
bad()  { printf '%s[FAIL]%s %s\n' "$C_BAD" "$C_RST" "$1"; FAILS=$((FAILS+1)); }
warn() { printf '%s[warn]%s %s\n' "$C_WARN" "$C_RST" "$1"; WARNS=$((WARNS+1)); }
note() { printf '%s      %s%s\n' "$C_DIM" "" "$1"; }
fix()  { printf '%s      fix: %s%s\n' "$C_DIM" "$1" "$C_RST"; }
sec()  { printf '\n%s== %s ==%s\n' "$C_B" "$1" "$C_RST"; }

printf '%s\n' "== mi50-p2p-check on $(uname -n), kernel $(uname -r) =="
note "Read-only gates below; --deep adds a small verified GPU-to-GPU copy."

# ---- Gate 1: GPUs present ---------------------------------------------------
sec "Gate 1 - MI50 / Vega 20 GPUs present"
GPU_BDFS=()
while read -r d _rest; do GPU_BDFS+=("$d"); done < <(lspci -D -d 1002:66a1 2>/dev/null)
NGPU=${#GPU_BDFS[@]}
if [ "$NGPU" -eq 0 ]; then
  bad "no 1002:66a1 (MI50/Vega 20) devices found - is this the right box? (lspci -d 1002:66a1)"
  printf '\nVERDICT: no MI50 GPUs found\n'; exit 2
fi
ok "$NGPU MI50 GPU(s):"
for b in "${GPU_BDFS[@]}"; do
  short=${b#0000:}
  note "  $b  $(lspci -s "$short" 2>/dev/null | sed 's/^[^ ]* //')"
done
[ "$NGPU" -lt 2 ] && warn "only 1 GPU - P2P is meaningless with a single card"

# ---- Gate 2: VBIOS ROM ------------------------------------------------------
sec "Gate 2 - VBIOS ROMs (P2P/ReBAR-capable 32 GB ROMs)"
KNOWN_VBIOS="113-D1631700-111 113-D1640200-043 113-D163A1XT-045"
VB_OK=1
if command -v rocm-smi >/dev/null 2>&1; then
  vbios_out=$(rocm-smi --showvbios 2>/dev/null | grep 'VBIOS version:' | awk '{print $NF}')
  if [ -z "$vbios_out" ]; then
    warn "rocm-smi returned no VBIOS versions (driver not loaded?)"
  else
    while read -r v; do
      [ -z "$v" ] && continue
      case " $KNOWN_VBIOS " in
        *" $v "*) note "  VBIOS $v : known-good P2P/ReBAR ROM" ;;
        *) warn "VBIOS $v : NOT in the known-good list - P2P may fail"
           fix "check the ROM matrix at https://gist.github.com/evilJazz/14a4c82a67f2c52a6bb5f9cea02f5e13 and flash a P2P-capable 32 GB ROM if needed"
           VB_OK=0 ;;
      esac
    done <<< "$vbios_out"
    [ "$VB_OK" -eq 1 ] && ok "all VBIOS ROMs known-good"
  fi
else
  warn "rocm-smi not found - cannot check VBIOS"
fi

# ---- Gate 3: GPU BARs below the 44-bit (16 TiB) DMA limit -------------------
sec "Gate 3 - GPU BARs below 16 TiB (gfx906 uses a 44-bit DMA mask)"
LIMIT=$(( 16#100000000000 ))
BAR_OK=1
for b in "${GPU_BDFS[@]}"; do
  short=${b#0000:}
  line=$(lspci -vv -s "$short" 2>/dev/null | grep -m1 'Region 0: Memory at')
  if [ -z "$line" ]; then
    warn "$b : no 64-bit prefetchable Region 0 BAR - is Above-4G decoding / ReBAR enabled in BIOS?"
    fix "BIOS: Above 4G Decoding=Enabled, Resizable BAR=Enabled"; BAR_OK=0; continue
  fi
  addr_hex=$(echo "$line" | awk '{print $5}')
  size_tok=$(echo "$line" | grep -oE 'size=[0-9]+[GM]' | head -1 | cut -d= -f2)
  case "$size_tok" in
    *G) size_bytes=$(( ${size_tok%G} * 1024 * 1024 * 1024 )) ;;
    *M) size_bytes=$(( ${size_tok%M} * 1024 * 1024 )) ;;
    *)  size_bytes=0 ;;
  esac
  start=$(( 16#$addr_hex ))
  end=$(( start + size_bytes ))
  if [ "$start" -ge "$LIMIT" ] || [ "$end" -gt "$LIMIT" ]; then
    bad "$b : VRAM BAR 0x$addr_hex (+${size_tok}) is ABOVE the 16 TiB limit - P2P will fail or corrupt"
    fix "lower MMIO High Base in BIOS (e.g. 1-4 T) so the 32 GB BARs sit below 16 TiB; do NOT raise the DMA mask (that path is corrupt on X99-class fabrics)"
    BAR_OK=0
  else
    note "$b : VRAM BAR 0x$addr_hex (+${size_tok}) - below 16 TiB [ok]"
  fi
done
[ "$BAR_OK" -eq 1 ] && ok "all VRAM BARs inside the 44-bit window"

# ---- Gate 4: kernel built with CONFIG_PCI_P2PDMA ----------------------------
sec "Gate 4 - kernel built with CONFIG_PCI_P2PDMA"
cfg_line=""
if [ -r "/boot/config-$(uname -r)" ]; then
  cfg_line=$(grep -m1 '^CONFIG_PCI_P2PDMA' "/boot/config-$(uname -r)" 2>/dev/null || true)
elif [ -r /proc/config.gz ] && command -v zcat >/dev/null 2>&1; then
  cfg_line=$(zcat /proc/config.gz 2>/dev/null | grep -m1 '^CONFIG_PCI_P2PDMA' || true)
fi
if [ "$cfg_line" = "CONFIG_PCI_P2PDMA=y" ]; then
  ok "CONFIG_PCI_P2PDMA=y (kernel $(uname -r))"
elif [ -n "$cfg_line" ]; then
  bad "$cfg_line - P2PDMA not built in; every 'P2P' run is a degraded host-staged fallback"
  fix "rebuild the kernel with CONFIG_PCI_P2PDMA=y (see DByte308/mi50-p2p-fixes)"
else
  warn "no CONFIG_PCI_P2PDMA line readable - cannot verify the kernel build"
fi

# ---- Gate 5: kernel's own P2P verdict in the log ----------------------------
sec "Gate 5 - kernel log verdict (PCIe P2P distance check)"
if command -v journalctl >/dev/null 2>&1 && journalctl -k --no-pager -n 1 >/dev/null 2>&1; then
  klog=$(journalctl -k --no-pager 2>/dev/null)
  n_rej=$(printf '%s\n' "$klog" | grep -c 'not supported by the chipset' || true)
  if [ "${n_rej:-0}" -eq 0 ]; then
    ok "0 'not supported by the chipset' P2P rejections this boot"
  else
    bad "$n_rej P2P rejections in the kernel log this boot"
    fix "the kernel's p2pdma distance/whitelist check fails: bridge not whitelisted or BARs too high (DByte308/mi50-p2p-fixes, 'three gates')"
  fi
  pairs=$(printf '%s\n' "$klog" | grep -oE 'amdgpu [0-9a-f:.]+: PCIe P2P access from peer device [0-9a-f:.]+' \
          | sed 's/amdgpu //; s/: PCIe P2P access from peer device / -> /' | sort -u)
  if [ -n "$pairs" ]; then
    ok "kernel grants P2P on $(printf '%s\n' "$pairs" | wc -l) directed pair(s):"
    printf '%s\n' "$pairs" | head -12 | sed 's/^/      /'
  else
    note "no 'PCIe P2P access' grants logged (normal when amdgpu enables P2P silently)"
  fi
else
  warn "kernel journal not readable (needs systemd-journal group or sudo) - skipped"
fi

# ---- Gate 6: amdgpu pcie_p2p parameter --------------------------------------
sec "Gate 6 - amdgpu module parameter pcie_p2p"
p2pp=$(cat /sys/module/amdgpu/parameters/pcie_p2p 2>/dev/null || true)
if [ "$p2pp" = "Y" ]; then
  ok "pcie_p2p=Y"
else
  warn "pcie_p2p='${p2pp:-unreadable}' - driver P2P not enabled (expected Y)"
  fix "check modprobe config: 'options amdgpu pcie_p2p=Y'"
fi

# ---- Gate 7: boot cmdline (iommu / acs / aspm) ------------------------------
sec "Gate 7 - boot cmdline (IOMMU / ACS / ASPM)"
cmdline=$(cat /proc/cmdline 2>/dev/null)
printf '%s\n' "$cmdline" | tr ' ' '\n' | grep -E '^(intel_iommu|amd_iommu|iommu|pcie_acs_override|pcie_aspm)' | sed 's/^/      /'
if printf '%s\n' "$cmdline" | grep -qE '(^| )(intel_iommu|amd_iommu|iommu)=(on|pt)'; then
  ok "IOMMU enabled on cmdline"
else
  warn "no IOMMU flag on cmdline - some Intel/PEX topologies need 'intel_iommu=on iommu=pt' (AMD: 'amd_iommu=on'); X99-class boxes also wanted pcie_acs_override=downstream,multifunction with a PLX switch"
fi

# ---- Gate 8: root complex grouping ------------------------------------------
sec "Gate 8 - GPUs vs root complexes"
RC_LIST=""
for b in "${GPU_BDFS[@]}"; do
  rc=$(readlink -f /sys/bus/pci/devices/"$b" 2>/dev/null | grep -oE 'pci[0-9a-f]+:[0-9a-f]+' | head -1)
  RC_LIST="$RC_LIST ${rc:-unknown}"
  note "  $b -> ${rc:-unknown}"
done
n_rcs=$(printf '%s\n' $RC_LIST | sort -u | wc -l)
if [ "$n_rcs" -eq 1 ]; then
  ok "all $NGPU GPUs under one root complex - best-case P2P topology"
else
  warn "GPUs span $n_rcs root complexes ($(printf '%s\n' $RC_LIST | sort -u | tr '\n' ' '))"
  fix "P2P can still work across RCs/switches but latency benefits are reduced (DByte308 PEX case study)"
fi

# ---- Gate 9: driver link matrix ---------------------------------------------
sec "Gate 9 - driver link matrix (rocm-smi --showtopoaccess)"
if command -v rocm-smi >/dev/null 2>&1; then
  topo=$(rocm-smi --showtopoaccess 2>/dev/null)
  if [ -z "$topo" ]; then
    warn "rocm-smi --showtopoaccess returned nothing (driver not loaded?)"
  else
    printf '%s\n' "$topo" | grep -E 'GPU[0-9]' | head -8 | sed 's/^/      /'
    n_true=$(printf '%s\n' "$topo" | grep -o 'True' | wc -l)
    n_false=$(printf '%s\n' "$topo" | grep -o 'False' | wc -l)
    if [ "$n_false" -gt 0 ]; then
      bad "link matrix has $n_false False entries - the driver does not allow P2P for those pairs"
      fix "usually a Gate 3/4/5 problem: BARs too high, kernel without P2PDMA, or bridge not whitelisted"
    elif [ "$n_true" -ge "$(( NGPU * (NGPU - 1) ))" ]; then
      ok "link matrix all True ($NGPU x $((NGPU - 1)) directed pairs)"
    else
      warn "link matrix: $n_true True / $n_false False - expected $(( NGPU * (NGPU - 1) )) True for $NGPU GPUs"
    fi
  fi
else
  warn "rocm-smi not found - cannot check driver link matrix"
fi

# ---- Gate 10: deep test (opt-in) --------------------------------------------
sec "Gate 10 - verified P2P copy (opt-in)"
DEEP_DONE=0
if [ "$DEEP" -eq 0 ]; then
  note "skipped - re-run with --deep for a real byte-verified GPU-to-GPU copy"
elif ! command -v hipcc >/dev/null 2>&1; then
  warn "--deep needs hipcc on the host; not found (or run the same test inside a ROCm container)"
else
  DEEP_DONE=1
  if [ -n "$PAIR" ]; then
    A=${PAIR%,*}; B=${PAIR#*,}
  else
    AB=$(rocm-smi --showuse 2>/dev/null | grep -oE 'GPU\[[0-9]+\].*use \(%\): [0-9]+' \
        | sed -E 's/GPU\[([0-9]+)\].*\): ([0-9]+)/\1 \2/' | sort -k2,2n | head -2 | cut -d' ' -f1 | paste -sd,)
    A=$(echo "$AB" | cut -d, -f1); B=$(echo "$AB" | cut -d, -f2)
  fi
  [ -z "$B" ] && { A=0; B=1; }
  note "pair: GPU $A <-> GPU $B, payload ${SIZE_KIB} KiB, both directions, re-seeded each direction"
  tmpd=$(mktemp -d /tmp/mi50p2p.XXXXXX)
  cat > "$tmpd/t.cu" <<'HIPCXX'
// verified bidirectional peer DMA copy - DMA only (hipMemcpyPeer), no kernel peer-reads.
#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
static void check(const char *w, hipError_t e) {
  if (e != hipSuccess) { printf("  !! %s: %s\n", w, hipGetErrorString(e)); exit(3); }
}
int main(int argc, char **argv) {
  int a = 0, b = 1; size_t N = 64u << 10;
  for (int i = 1; i < argc - 1; i++) {
    if (!strcmp(argv[i], "--pair"))  { sscanf(argv[++i], "%d,%d", &a, &b); }
    else if (!strcmp(argv[i], "--bytes")) { N = (size_t)atoll(argv[++i]); }
  }
  if (N == 0) N = 64u << 10;
  int n = 0; check("hipGetDeviceCount", hipGetDeviceCount(&n));
  if (a < 0 || b < 0 || a >= n || b >= n || a == b) {
    printf("  !! pair (%d,%d) out of range (have %d devices)\n", a, b, n); return 4; }
  int ca = 0, cb = 0;
  hipDeviceCanAccessPeer(&ca, a, b);
  hipDeviceCanAccessPeer(&cb, b, a);
  printf("canAccessPeer %d->%d = %d, %d->%d = %d\n", a, b, ca, b, a, cb);
  if (!ca || !cb) { printf("DRIVER-GATE-FAIL: hipDeviceCanAccessPeer is 0 - data path not allowed; see gates 3-5\n"); return 5; }
  float *h = nullptr;
  check("hipHostMalloc", hipHostMalloc(&h, N, hipHostMallocDefault));
  void *sa = nullptr, *sb = nullptr;
  hipSetDevice(a); check("hipMalloc A", hipMalloc(&sa, N));
  hipSetDevice(b); check("hipMalloc B", hipMalloc(&sb, N));
  int rc = 0;
  for (int dir = 0; dir < 2; dir++) {
    int src = dir ? b : a, dst = dir ? a : b;
    void *sptr = src == a ? sa : sb, *dptr = dst == a ? sa : sb;
    // FRESH pattern every direction - never reuse complement patterns without re-seed
    // (that test artifact made a clean box look corrupt; DByte308 write-up)
    for (size_t i = 0; i < N / sizeof(float); i++) h[i] = (float)((i + (size_t)dir * 977u) % 251u);
    hipSetDevice(src); check("H2D seed", hipMemcpy(sptr, h, N, hipMemcpyHostToDevice));
    hipSetDevice(dst); check("EnablePeerAccess", hipDeviceEnablePeerAccess(src, 0));
    hipEvent_t t0, t1;
    check("ev", hipEventCreate(&t0)); check("ev", hipEventCreate(&t1));
    check("rec", hipEventRecord(t0));
    hipError_t cp = hipMemcpyPeer(dptr, dst, sptr, src, N);
    check("rec", hipEventRecord(t1)); check("sync", hipEventSynchronize(t1));
    float ms = 0.f; hipEventElapsedTime(&ms, t0, t1);
    if (cp != hipSuccess) {
      printf("%d->%d hipMemcpyPeer FAILED: %s\n", src, dst, hipGetErrorString(cp)); rc = 1; continue; }
    hipSetDevice(dst); check("D2H back", hipMemcpy(h, dptr, N, hipMemcpyDeviceToHost));
    long badn = 0;
    for (size_t i = 0; i < N / sizeof(float); i++)
      if (h[i] != (float)((i + (size_t)dir * 977u) % 251u)) {
        if (!badn) printf("first mismatch at word %zu: got %.1f want %.1f\n", i, h[i], (float)((i + (size_t)dir * 977u) % 251u));
        badn++; }
    if (badn) { printf("%d->%d CORRUPT: %ld/%zu words wrong - 'enabled but corrupt' (BAR/fabric issue)\n", src, dst, badn, N / sizeof(float)); rc = 1; }
    else printf("%d->%d OK: %zu bytes bit-exact, %.2f ms, %.2f GB/s\n", src, dst, N, ms, (double)N / (ms * 1e6));
  }
  hipFree(sa); hipFree(sb); hipHostFree(h);
  printf(rc ? "DEEP-FAIL\n" : "DEEP-OK\n");
  return rc;
}
HIPCXX
  if ! hipcc -O1 -o "$tmpd/t" "$tmpd/t.cu" 2>"$tmpd/cc.err"; then
    warn "hipcc compile failed:"
    sed 's/^/      /' "$tmpd/cc.err" | head -8
    DEEP_DONE=0
  else
    note "compiling took a moment; running the transfer test (timeout 120 s)"
    out=$(timeout 120 "$tmpd/t" --pair "$A,$B" --bytes "$SIZE_BYTES" 2>&1); rc=$?
    printf '%s\n' "$out" | sed 's/^/      /'
    case "$rc" in
      0) ok "verified P2P copy passed both directions - P2P is REAL on this pair" ;;
      5) bad "hipDeviceCanAccessPeer = 0 - the driver gate itself says no (see gates 3-5)" ;;
      1) bad "transfer reported CORRUPT or failed - P2P 'enabled but corrupt'; do not trust it"
         fix "the BAR/fabric gate is the issue; do not raise the DMA mask" ;;
      *) bad "deep test crashed or timed out (rc=$rc) - stop here, do not repeat P2P experiments until that is understood"
         fix "a GPU fault here means the fabric path is bad (documented P2P crash pattern); check dmesg/journal" ;;
    esac
  fi
  rm -rf "$tmpd"
fi

# ---- Launcher/env cheat-sheet -----------------------------------------------
sec "If P2P passes: the vLLM/NCCL side (gfx906-hub runbook)"
note "env:  NCCL_P2P_LEVEL=PXB|PIX|SYS  RCCL_P2P_DISABLE=0  VLLM_SKIP_P2P_CHECK=1  HSA_FORCE_FINE_GRAIN_PCIE=1"
note "flag: --disable-custom-all-reduce when using >2 GPUs (forces RCCL over vLLM's default all-reduce)"
note "proof in engine logs:  'via P2P/IPC' = working   /   'via SHM/direct' = fell back to system RAM"

# ---- Verdict ----------------------------------------------------------------
sec "VERDICT"
if [ "$FAILS" -gt 0 ]; then
  printf '%sP2P BLOCKED - %d gate(s) failing.%s Fix the FAIL lines above (each carries a fix); reboot if a BIOS/cmdline gate was changed.\n' "$C_BAD" "$FAILS" "$C_RST"
  exit 1
elif [ "$DEEP_DONE" -eq 1 ] && [ "$WARNS" -eq 0 ]; then
  printf '%sP2P WORKING - all gates pass and the verified copy is byte-exact.%s\n' "$C_OK" "$C_RST"
  exit 0
elif [ "$DEEP_DONE" -eq 1 ]; then
  printf '%sP2P WORKS (verified copy) but %d warning(s) above worth a look.%s\n' "$C_OK" "$WARNS" "$C_RST"
  exit 0
else
  printf '%sGATES PASS, transfer UNVERIFIED - run with --deep for the byte-exact check.%s\n' "$C_WARN" "$C_RST"
  [ "$WARNS" -gt 0 ] && printf '%s(%d warning(s) above.)%s\n' "$C_WARN" "$WARNS" "$C_RST"
  exit 0
fi
