# MI50 / gfx906 Hub

Community hub for LLM serving on AMD **MI50 (gfx906 — Vega 20)**: what's moving in the
tracked forks, and the standing setup notes.

> Status rows below are **auto-updated nightly**.

## Tracked repos

<!-- HUB-STATUS:BEGIN -->
### vllm

| repo | focus | updated | head | version |
|---|---|---|---|---|
| [ttdxq/gfx906-vllm](https://github.com/ttdxq/gfx906-vllm) | open kernel-source fork (GDN decode stack) + RCCL gfx906 builds | 2026-11-08 | `3eeb931d` | [rccl-gfx906-2.27.7-rocm7.2.4](https://github.com/ttdxq/gfx906-vllm/releases/tag/rccl-gfx906-2.27.7-rocm7.2.4) |
| [KIntegrated/vllm-gfx906-mobydick](https://github.com/KIntegrated/vllm-gfx906-mobydick) | newest vLLM base (v0.31 line) — current release gfx906/v0.31.0-final | 2026-10-26 | `3857591d` | gfx906/v0.31.0-final |
| [0c33/mi50-vllm-lab](https://github.com/0c33/mi50-vllm-lab) | 27B on 2× MI50 — gfx906_skinny 4-bit kernels (lab / experiments) | 2026-10-26 | `eb3b1728` | — |
| [mixa3607/ML-gfx906](https://github.com/mixa3607/ML-gfx906/blob/master/vllm-v2/README.md) | the base monorepo — vllm, llama.cpp, strata (+ more) for gfx906 | 2026-10-19 | `10d3897f` | [20261115214657](https://github.com/mixa3607/ML-gfx906/releases/tag/20261115214657) |
| [joochung/vllm-gfx906-mobydick](https://github.com/joochung/vllm-gfx906-mobydick) | PLE CPU-offload — big MoE models on 16GB cards (v0.30 line) | 2026-10-17 | `524ac6f2` | v0.30-first-good-boot |
| [ai-infos/vllm-gfx906-mobydick](https://github.com/ai-infos/vllm-gfx906-mobydick) | multi-GPU / TP4 serving (the 4×MI50 P2P guide runs on this image) | 2026-10-08 | `e7b96a5e` | — |
| [phantomic12/ML-gfx906](https://github.com/phantomic12/ML-gfx906) | mixa monorepo fork (dormant) — GitHub-hosted apt-repo build POC | 2026-08-16 | `e816905b` | [20260802001858](https://github.com/phantomic12/ML-gfx906/releases/tag/20260802001858) |
| [joe2gaan/localaiservers](https://github.com/joe2gaan/localaiservers) | vNext vLLM — closed .so runtime overlay, dense + MoE profiles, bench reports | 2026-07-01 | `3502012d` | [vnext-gfx906-rocm72-gguf-hf-repro](https://github.com/joe2gaan/localaiservers/releases/tag/vnext-gfx906-rocm72-gguf-hf-repro) |
| [cassettesgoboom/gfx906-fa-vllm](https://github.com/cassettesgoboom/gfx906-fa-vllm) | flash-attention kernels for gfx906 (feeds the gfx906_fa vLLM backend) | 2026-04-22 | `e0eb52a3` | — |

### llamacpp

| repo | focus | updated | head | version |
|---|---|---|---|---|
| [AlwaysLearning-dev/gfx906-llama-cpp](https://github.com/AlwaysLearning-dev/gfx906-llama-cpp/tree/dev_v2) | 2× MI50 tensor-split llama.cpp — Qwen3.8-27B Q8_0 + DFlash2 drafter; dev_v2 = Q8_0 weight repack (~434 pp tok/s) | 2026-11-20 | `36e84ddb` | — |
| [sixvolts/llamacpp-gfx906-furnace](https://github.com/sixvolts/llamacpp-gfx906-furnace) | retuned llama.cpp — 177B Qwen3.8-Flash-Next MoE (UD-Q4_K_XL) layer-split across 4× MI50, GCN weight repack + DPP warp reductions | 2026-11-10 | `d2b95132` | gfx906-perf-b9607-5013b9f |
| [mxxm-t/mx-llama.cpp](https://github.com/mxxm-t/mx-llama.cpp) | llama.cpp mx builds — Qwen3 / 3.5 GGUF quants (Q8 to Q4) on 16GB | 2026-11-18 | `557a6068` | b12717 |
| [mixa3607/ML-gfx906](https://github.com/mixa3607/ML-gfx906/blob/master/llama.cpp/README.md) | the base monorepo — vllm, llama.cpp, strata (+ more) for gfx906 | 2026-10-19 | `c163a5d9` | [20261115214657](https://github.com/mixa3607/ML-gfx906/releases/tag/20261115214657) |
| [benpeterson40/castagna-veloce](https://github.com/benpeterson40/castagna-veloce) | llama.cpp fork built for MI50 — 2–8 cards over PCIe, TP + MTP/DSpark speculative decoding (DeepSeek V4 Flash, GLM-5.3-Flash, Qwen3.8) | 2026-10-07 | `3483d462` | main-b11108-3483d46 |
| [anng-phtk/rocm-vega-llama.cpp](https://github.com/anng-phtk/rocm-vega-llama.cpp) | mixed-GPU llama.cpp (Vega 64 + MI50) on ROCm 7.2 | 2026-08-25 | `602a7b55` | — |

### strata

| repo | focus | updated | head | version |
|---|---|---|---|---|
| [hboyd2003/Strata](https://github.com/hboyd2003/Strata) | Strata tuned for gfx906 — rocBLAS autotune, prompt-attention env (~+7% prefill) | 2026-11-18 | `5958a581` | [v0.2.13+0.5-gfx906](https://github.com/hboyd2003/Strata/releases/tag/v0.2.13%2B0.5-gfx906) |
| [mixa3607/ML-gfx906](https://github.com/mixa3607/ML-gfx906/blob/master/strata/README.md) | the base monorepo — vllm, llama.cpp, strata (+ more) for gfx906 | 2026-10-27 | `9579d9bf` | [20261115214657](https://github.com/mixa3607/ML-gfx906/releases/tag/20261115214657) |

### llaminar

| repo | focus | updated | head | version |
|---|---|---|---|---|
| [Llaminar/llaminar](https://github.com/Llaminar/llaminar) | standalone C++ GGUF engine with first-class MI50 (gfx906) support — Qwen 3/3.5/3.6/3.8 (dense + MoE) | 2026-11-19 | `61f45187` | [2026-09-27.1](https://github.com/Llaminar/llaminar/releases/tag/2026-09-27.1) |

<!-- HUB-STATUS:END -->

## Common info

### gfx906 Discord

[gfx906 Discord invite](https://discord.gg/VSqu8gXq2) — the MI50 / gfx906 community.

### P2P Guide

[mi50-p2p-fixes](https://github.com/DByte308/mi50-p2p-fixes) — DByte308's PCIe P2P write-up for the MI50 (X99 three-gate story + four-MI50 + 7900 XTX case study).

### MI50 VBIOS reference

[MI50 32GB VBIOS](https://gist.github.com/evilJazz/14a4c82a67f2c52a6bb5f9cea02f5e13)
— evilJazz's consolidated VBIOS ROM reference: the ROM matrix (P2P support, ReBAR,
power caps, clocks), original vs modified PCB, amdvbflash flashing, and UPP overrides.

## Change log


[CHANGELOG.md](CHANGELOG.md) — every repo move, newest first.

<!-- HUB-FOOTER:BEGIN -->
_Hub status last refreshed: 2026-11-21 12:27 UTC — 16 tracked, 0 unreachable._
<!-- HUB-FOOTER:END -->
