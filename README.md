# Local LLM Hardware Calculator

Single-file web calculator that answers the most common question in local AI:
**will this model fit in my GPU, or do I need to offload to system RAM?**

Enter your RAM, VRAM, model size and quantization and it tells you, in plain
language, whether the model runs 100% on the GPU (fastest), needs an
offload split, or exceeds your total capacity — plus an estimated
generation speed in tokens/s.

Built for people running models locally with **LM Studio, Ollama, llama.cpp,
Jan, text-generation-webui, Roo Code and friends**.

## Live demo

**https://devilstar333.github.io/llm-hardware-calculator/**

(English by default; use the **PT** button in the header for Portuguese, or open
`.../?lang=pt`.)

## What it tells you

| Verdict | Meaning |
|---|---|
| ✅ **100% VRAM** | The whole model fits in the GPU. Ideal case: maximum speed, no system RAM traffic. |
| ⚠️ **Offload (GPU + RAM)** | It fits, but part of it lands in system RAM. Shows the exact split in GB, and you tune it with `n_gpu_layers`. |
| ❌ **Won't run** | Exceeds RAM + VRAM. Shows how much memory is missing and what to try next. |
| ⚠️ **Fits with little headroom** | More than 90% of usable VRAM used — one bigger context and you get an OOM. |

It also suggests the best quantization that *would* fit entirely in VRAM,
and estimates generation speed (tokens/s) from memory bandwidth.

## How the estimate works

```
weights        = parameters (B) × effective bits ÷ 8
overhead       = 20% of the weights + 0.6 GB (compute/runtime buffers)
KV cache       ≈ 0.007 GB × billions of parameters × (context ÷ 1024)
total          = weights + overhead + KV cache
usable VRAM    = VRAM − display reserve (default 0.75 GB)
usable RAM     = RAM − OS/apps reserve  (default 2.5 GB)
speed (tok/s)  ≈ effective bandwidth ÷ total memory   (GPU ~600 GB/s, DDR5 ~80 GB/s)
```

Effective bits per weight: `Q4_K_M ≈ 4.5`, `Q6_K ≈ 6.5`, `Q8_0 ≈ 8.5`, `FP16 = 16`.
A "simple community formula" mode (`weights × 1.2`, no KV cache, no reserves)
is available in the advanced panel for comparison.

**These are approximations.** MoE architectures, quantized KV cache,
layer-split multi-GPU and prompt processing are not modeled. Use the numbers
as an order of magnitude to decide what to download — not as a guarantee.

## Features

- **Any quantization** in a data table — adding a new one is a one-line change.
- **Live recalculation** on every keystroke, with inline validation.
- **Deep links / shareable results**: `index.html?ram=32&vram=12&params=24&quant=q4_k_m&ctx=8192&lang=en`
- **Copy summary** button — puts a plain-text report (including the share
  link) on your clipboard, ready to paste into a forum or issue.
- **English by default, Portuguese via the language toggle** (persisted, and
  `?lang=pt` overrides it). Dictionary-based i18n, ~140 keys per language.
- **Dark theme by default**, light theme toggle, responsive down to mobile.
- **Accessible**: labelled inputs, `aria-live` result, keyboard navigable.
- **No build step, no dependencies, no tracking.**

## URL parameters

| Parameter | Values | Default |
|---|---|---|
| `ram` | GB (integer or decimal) | `32` |
| `vram` | GB | `12` |
| `params` | billions of parameters | `24` |
| `quant` | `q4_k_m`, `q6_k`, `q8_0`, `fp16` | `q4_k_m` |
| `ctx` | `2048` … `131072` | `8192` |
| `lang` | `en`, `pt` | `en` |
| `theme` | `dark`, `light` | `dark` |
| `strict` | `1` (simple community formula) | off |
| `vramreserve`, `ramreserve` | GB | `0.75`, `2.5` |
| `debug` | `1` (logs missing i18n keys) | off |

## Running it locally

No tooling required — open `index.html` in a browser. To serve it over HTTP
(needed for the copy-to-clipboard API on some browsers):

```bash
python -m http.server 8000
# then open http://localhost:8000
```

## Privacy

The calculation runs entirely in the browser; nothing you type is sent
anywhere. The only third-party requests are the Tailwind Play CDN and Google
Fonts (both required for styling). No analytics, no ads, no cookies.

## Tech

One `index.html` with inline CSS and JavaScript, styled with Tailwind via CDN.
No framework, no bundler, no `node_modules`.

## License

_TBD — add a `LICENSE` file before publishing (MIT is a good fit for a tool
like this)._
