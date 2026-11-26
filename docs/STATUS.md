# STATUS — generated

> Regenerated every 15 minutes by `gfx906-hub-check.py`; a run commits only when the table changes.
> The README blocks are the digest of this file. Hand edits will be overwritten.

_Last data change: 2026-11-26._

| repo | category | role | ref | head | updated | version | compare |
|---|---|---|---|---|---|---|---|
| cassettesgoboom/gfx906-fa-vllm | vllm | gfx906 flash-attention kernels for vLLM (upstream of the gfx906_fa backend) | `HEAD` | `e0eb52a3` | 2026-04-22 | - | - |
| KIntegrated/vllm-gfx906-mobydick | vllm | gfx906 vLLM fork (mobydick) | `HEAD` | `3857591d` | 2026-10-26 | gfx906/v0.31.0-final | - |
| ai-infos/vllm-gfx906-mobydick | vllm | gfx906 vLLM fork (mobydick — ai-infos branch; Radeon VII / MI50 / MI60) | `HEAD` | `e7b96a5e` | 2026-10-08 | - | - |
| 0c33/mi50-vllm-lab | vllm | MI50 vLLM lab — 27B on 2x MI50, gfx906_skinny 4-bit kernels | `HEAD` | `eb3b1728` | 2026-10-26 | - | - |
| ttdxq/gfx906-vllm | vllm | open .cu gfx906 vLLM fork (GDN decode stack) | `HEAD` | `3eeb931d` | 2026-11-08 | [rccl-gfx906-2.27.7-rocm7.2.4](https://github.com/ttdxq/gfx906-vllm/releases/tag/rccl-gfx906-2.27.7-rocm7.2.4) | - |
| mixa3607/ML-gfx906 | vllm, llamacpp, strata | gfx906 ML base (upstream of the cassettesgoboom FA work) — single monorepo; row appears under each tracked project, linking to that project's subproject | `HEAD` | `5f6913c5` | 2026-11-23 | [20261123223821](https://github.com/mixa3607/ML-gfx906/releases/tag/20261123223821) | https://github.com/mixa3607/ML-gfx906/compare/ab2a93dedafc6c4cb222008f478b4032bb22f2ac...5f6913c583110a559407142f93577a1e956c9f91 |
| mxxm-t/mx-llama.cpp | llamacpp | llama.cpp fork (mx build) | `HEAD` | `557a6068` | 2026-11-18 | b12717 | https://github.com/mxxm-t/mx-llama.cpp/compare/cdc81dae4f4362e0aeaeb99c90622b9de4504d53...557a6068f4c5c8fb0ba9982d2a912eeeb2dcaa08 |
| joochung/vllm-gfx906-mobydick | vllm | gfx906 vLLM fork (IMJoo's mobydick line — PLE CPU-offload integration + QSA-FN branches) | `HEAD` | `524ac6f2` | 2026-10-17 | v0.30-first-good-boot | - |
| anng-phtk/rocm-vega-llama.cpp | llamacpp | llama.cpp on ROCm 7.2 for Vega 64 (gfx900) + MI50 (gfx906) — mixed-GPU inference | `HEAD` | `602a7b55` | 2026-08-25 | - | - |
| phantomic12/ML-gfx906 | vllm | gfx906 ML builds monorepo (fork of mixa3607/ML-gfx906) — GitHub-hosted apt repo POC (dormant) | `HEAD` | `e816905b` | 2026-08-16 | [20260802001858](https://github.com/phantomic12/ML-gfx906/releases/tag/20260802001858) | - |
| hboyd2003/Strata | strata | Strata gfx906 build — rocBLas autotune at startup, STRATA_PROMPT_ATTN_GFX906 (v0.2.12+0.4-gfx906) | `HEAD` | `3053e831` | 2026-11-26 | [v0.2.22+0.6-gfx906](https://github.com/hboyd2003/Strata/releases/tag/v0.2.22%2B0.6-gfx906) | https://github.com/hboyd2003/Strata/compare/f89e2ce1e5f627d79c4f143d012688e275ff675c...3053e831bee266ceed727189a53331e4a64008a9 |
| joe2gaan/localaiservers | vllm | vNext vLLM fork (joe2gaan) — closed .so overlay, gfx906 deploy scripts, bench reports | `HEAD` | `3502012d` | 2026-07-01 | [vnext-gfx906-rocm72-gguf-hf-repro](https://github.com/joe2gaan/localaiservers/releases/tag/vnext-gfx906-rocm72-gguf-hf-repro) | - |
| Llaminar/llaminar | llaminar | Llaminar — C++ GGUF inference engine (CPU / CUDA / ROCm); explicit MI50 gfx906 support, e2e-tested recipes | `HEAD` | `61f45187` | 2026-11-24 | [2026-09-27.1](https://github.com/Llaminar/llaminar/releases/tag/2026-09-27.1) | https://github.com/Llaminar/llaminar/compare/454741b1b2228bc6874e46ade75bbf523a8385d5...61f451871b734c4a6511a8d7d60135b040a28808 |
| sixvolts/llamacpp-gfx906-furnace | llamacpp | llama.cpp retune for gfx906 (weight repacking, DPP/ds_swizzle reductions, 4×MI50 MoE serving) — the furnace/reinstinct line | `HEAD` | `d2b95132` | 2026-11-10 | gfx906-perf-b9607-5013b9f | - |
| benpeterson40/castagna-veloce | llamacpp | Castagna Veloce — llama.cpp fork tuned for single-GPU MI50, scaled to 2–8 cards (gfx906 kernels, MoE-era fusions, TP over plain PCIe) | `HEAD` | `3483d462` | 2026-10-07 | main-b11108-3483d46 | - |
| AlwaysLearning-dev/gfx906-llama-cpp | llamacpp | llama.cpp for dual MI50 tensor split (DFlash2 speculative decoding); tracked on the dev_v2 branch (newest, in testing) | `dev_v2` | `36e84ddb` | 2026-11-20 | - | https://github.com/AlwaysLearning-dev/gfx906-llama-cpp/compare/77941dd7acad8e9932a5e7e147befe8706e73e77...36e84ddb7e5792af6994ee79e12452ba4c918e63 |
| rayakame/llama.cpp-gfx906 | llamacpp | llama.cpp tuned for Qwen3.8 27B on the AMD Instinct MI50 (gfx906) | `HEAD` | `0e14dfab` | 2026-11-25 | [gfx906-v0.7.1](https://github.com/rayakame/llama.cpp-gfx906/releases/tag/gfx906-v0.7.1) | https://github.com/rayakame/llama.cpp-gfx906/compare/97d72a3dd2171813ba9b2ab3fcce3d7e6a5ddb5e...0e14dfab5d907e4290da252488f46adae50ebc5d |
