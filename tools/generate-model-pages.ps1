# Gera as páginas por modelo (/models/<slug>/) e o /models/index.html,
# alem de reescrever o sitemap.xml. Os numeros saem da MESMA formula do
# index.html, entao nunca divergem do que a calculadora mostra.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\generate-model-pages.ps1
# Adicionar um modelo = adicionar uma linha em $models e rodar de novo.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$base = 'https://devilstar333.github.io'
$tag  = 'llmcalculator-20'
$today = (Get-Date).ToString('yyyy-MM-dd')

# ---- hipoteses do modelo (iguais as do index.html) ----
$overheadPct = 0.20
$runtimeGB   = 0.60
$kvPerBPer1k = 0.007
$vramReserve = 0.75
$ctxDefault  = 8192
$reserveTxt  = $vramReserve.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture)

$quants = @(
  @{ id = 'q4_k_m'; label = 'Q4_K_M'; bits = 4.5; note = 'most used' },
  @{ id = 'q6_k';   label = 'Q6_K';   bits = 6.5; note = 'higher quality' },
  @{ id = 'q8_0';   label = 'Q8_0';   bits = 8.5; note = 'near lossless' },
  @{ id = 'fp16';   label = 'FP16';   bits = 16;  note = 'unquantized' }
)

# faixas de VRAM existentes no mercado
$tiers = @(8, 12, 16, 20, 24, 32, 48, 64, 80, 96, 128, 192, 256, 384, 512, 768, 1024)

function Get-Total([double]$params, [double]$bits, [int]$ctx) {
  $w  = $params * $bits / 8
  $kv = $params * $kvPerBPer1k * ($ctx / 1024)
  return [Math]::Round($w * (1 + $overheadPct) + $runtimeGB + $kv, 1)
}
function Get-Tier([double]$needed) {
  foreach ($t in $tiers) { if ($t -ge $needed) { return $t } }
  return $null
}
function Fmt([double]$n) { return $n.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) }

# ---- catalogo de modelos (nome, parametros totais em bilhoes, contexto tipico) ----
$models = @(
  @{ slug = 'qwen3-32b';           name = 'Qwen3 32B';            params = 32;  ctx = 32768; family = 'Qwen3 (Alibaba)';        kind = 'dense';
     blurb = 'A dense 32B model with strong reasoning and multilingual text. One of the most downloaded 32B checkpoints, and the classic jump from 8B to serious local quality.' },
  @{ slug = 'qwen3-30b-a3b';       name = 'Qwen3 30B A3B';        params = 30;  ctx = 32768; family = 'Qwen3 MoE (Alibaba)';    kind = 'moe';
     blurb = 'Mixture-of-experts: about 30B parameters in memory but only ~3B active per token, so it generates much faster than a dense 30B — if it fits in memory at all.' },
  @{ slug = 'llama-3.3-70b';       name = 'Llama 3.3 70B';        params = 70;  ctx = 8192;  family = 'Llama (Meta)';              kind = 'dense';
     blurb = 'Meta&rsquo;s 70B dense model: excellent general quality, and the classic reason people discover they need far more VRAM than they have.' },
  @{ slug = 'llama-3.1-8b';        name = 'Llama 3.1 8B';         params = 8;   ctx = 8192;  family = 'Llama (Meta)';              kind = 'dense';
     blurb = 'The default starter model for local AI. Small enough to run entirely on a mid-range GPU with room for a long context.' },
  @{ slug = 'mistral-small-24b';   name = 'Mistral Small 24B';    params = 24;  ctx = 32768; family = 'Mistral AI';               kind = 'dense';
     blurb = 'A strong 24B model with a 32k context. Popular on 12-16 GB cards with offload, and comfortable on 24 GB.' },
  @{ slug = 'gemma-3-27b';         name = 'Gemma 3 27B';          params = 27;  ctx = 32768; family = 'Gemma (Google)';           kind = 'dense';
     blurb = 'Google&rsquo;s 27B multimodal-capable model: strong quality, and it lands right between the 24 GB and 32 GB tiers.' },
  @{ slug = 'deepseek-r1-distill-32b'; name = 'DeepSeek-R1 Distill 32B'; params = 32; ctx = 32768; family = 'DeepSeek-R1 distill';  kind = 'dense';
     blurb = 'A reasoning model distilled into a 32B backbone. It thinks before answering, so expect a much longer output per prompt.' },
  @{ slug = 'phi-4-14b';           name = 'Phi-4 14B';            params = 14;  ctx = 16384; family = 'Phi (Microsoft)';          kind = 'dense';
     blurb = 'A compact 14B model with reasoning-heavy training data. One of the best quality-per-gigabyte options for 12-16 GB cards.' }
)

$navModels = ($models | ForEach-Object { $_.name }) -join ' &middot; '

$TPL_TOP = @'
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="color-scheme" content="dark light" />
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Crect width='24' height='24' rx='5' fill='%23020617'/%3E%3Crect x='5' y='5' width='14' height='14' rx='3' fill='none' stroke='%2310b981' stroke-width='1.6'/%3E%3Crect x='9.5' y='9.5' width='5' height='5' rx='1' fill='%2310b981'/%3E%3C/svg%3E" />
<title>{{TITLE}}</title>
<meta name="description" content="{{DESC}}" />
<meta property="og:type" content="article" />
<meta property="og:title" content="{{TITLE}}" />
<meta property="og:description" content="{{DESC}}" />
<meta property="og:locale" content="en_US" />
<meta property="og:locale:alternate" content="pt_BR" />
<meta name="twitter:card" content="summary" />
<link rel="canonical" href="{{CANON}}" />
<script src="https://cdn.tailwindcss.com"></script>
<script>
  tailwind.config = { darkMode: 'class', theme: { extend: { fontFamily: { sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'], mono: ['JetBrains Mono', 'ui-monospace', 'monospace'] } } } };
</script>
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet" />
<style>
  html { color-scheme: dark; }
  body { background-color: #020617; color: #e2e8f0; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
  table { border-collapse: collapse; }
  th, td { border-bottom: 1px solid rgb(255 255 255 / .08); }
  tbody tr:hover { background: rgb(255 255 255 / .03); }
</style>
<script type="application/ld+json">{{JSONLD}}</script>
</head>
<body class="min-h-screen bg-slate-950 text-slate-100 antialiased">
<header class="border-b border-white/10">
  <div class="mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-5 sm:px-6">
    <a href="/" class="flex items-center gap-3 no-underline">
      <span class="grid h-10 w-10 place-items-center rounded-xl bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/30">
        <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><rect x="4" y="4" width="16" height="16" rx="3" /><rect x="9" y="9" width="6" height="6" rx="1" /><path d="M9 2v2M15 2v2M9 20v2M15 20v2M2 9h2M2 15h2M20 9h2M20 15h2" /></svg>
      </span>
      <span class="text-sm font-extrabold tracking-tight sm:text-base">Local LLM Hardware Calculator</span>
    </a>
    <a href="/" class="rounded-xl bg-emerald-500 px-3.5 py-2 text-xs font-bold text-slate-950 transition hover:bg-emerald-400">Open the calculator &rarr;</a>
  </div>
</header>

<main class="mx-auto max-w-5xl px-4 py-10 sm:px-6">
  <p class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-400">Model VRAM guide</p>
  <h1 class="mt-2 text-2xl font-extrabold leading-tight sm:text-4xl">{{H1}}</h1>
  <p class="mt-4 max-w-3xl text-sm leading-relaxed text-slate-300 sm:text-base">{{BLURB}}</p>
  <p class="mt-3 max-w-3xl text-sm leading-relaxed text-slate-300 sm:text-base">
    Below: the memory each quantization needs at a {{CTX}} token context (weights + runtime overhead + KV cache, with a
    {{RESERVE}} GB display reserve), which one fits <strong>entirely</strong> on a GPU, and what to expect when it does not.
    The numbers come from the same formula as the
    <a class="font-semibold text-emerald-400 underline decoration-dotted" href="/">interactive calculator</a>.
  </p>

  <section class="mt-8">
    <h2 class="text-xl font-extrabold sm:text-2xl">Memory needed at {{CTX}} context</h2>
    <div class="mt-4 overflow-x-auto rounded-2xl border border-white/10">
      <table class="w-full min-w-[640px] text-sm">
        <thead class="bg-white/[0.04] text-xs uppercase tracking-wider text-slate-400">
          <tr>
            <th class="px-4 py-3 text-left">Quantization</th>
            <th class="px-4 py-3 text-right">Total memory</th>
            <th class="px-4 py-3 text-left">Fits 100% on the GPU with</th>
            <th class="px-4 py-3 text-right">Check yours</th>
          </tr>
        </thead>
        <tbody class="text-slate-200">
{{ROWS}}
        </tbody>
      </table>
    </div>
    <p class="mt-3 text-xs text-slate-500">{{SUBTITLE}}</p>
  </section>

  <section class="mt-8 rounded-2xl border border-white/10 bg-white/[0.03] p-5">
    <h2 class="text-sm font-bold uppercase tracking-wider text-slate-400">The short answer</h2>
    <p class="mt-3 text-sm leading-relaxed text-slate-200">{{SHORT}}</p>
    <p class="mt-3 text-xs leading-relaxed text-slate-400">{{OFFLOAD}}</p>
  </section>
'@

$TPL_BOTTOM = @'
{{AMAZON}}
{{FAQ}}
  <section class="mt-10 rounded-2xl border border-emerald-500/30 bg-emerald-500/[0.07] p-6 text-center">
    <h2 class="text-lg font-extrabold sm:text-xl">Check {{NAME}} against your own hardware</h2>
    <p class="mx-auto mt-2 max-w-2xl text-sm text-slate-300">The calculator opens pre-filled with {{PARAMS}}B and Q4_K_M &mdash; change your RAM and VRAM to see whether it fits, needs offload, or exceeds your total memory.</p>
    <a href="/?params={{PARAMS}}&quant=q4_k_m&ctx={{CTX}}" class="mt-4 inline-block rounded-xl bg-emerald-500 px-5 py-2.5 text-sm font-bold text-slate-950 transition hover:bg-emerald-400">Open the calculator &rarr;</a>
    <p class="mt-3 text-xs text-slate-400">Free, no sign-up, and nothing you type leaves your browser.</p>
  </section>

  <section class="mt-10">
    <h2 class="text-xl font-extrabold sm:text-2xl">Other models</h2>
    <p class="mt-3 flex flex-wrap gap-x-3 gap-y-2 text-sm">{{RELATED}}</p>
    <p class="mt-4 text-xs text-slate-500"><a class="font-semibold text-emerald-400 underline decoration-dotted" href="/vram-requirements/">See the full VRAM table for every model size &rarr;</a></p>
  </section>
</main>

<footer class="border-t border-white/10">
  <div class="mx-auto max-w-5xl px-4 py-8 text-xs leading-relaxed text-slate-400 sm:px-6">
    <p>
      Estimates based on the community formula (weights + 20% overhead + 0.6 GB + KV cache). Real usage varies with the
      architecture, grouped-query attention settings, KV cache quantization and prompt processing. Treat them as an order
      of magnitude, not a guarantee. Quantized files are usually published by the community (bartowski, unsloth and
      others) and the exact size differs slightly between revisions.
    </p>
    <p class="mt-3">
      <a class="font-semibold text-emerald-400 underline decoration-dotted" href="/">Calculator</a> &middot;
      <a class="font-semibold text-emerald-400 underline decoration-dotted" href="/vram-requirements/">VRAM guide</a> &middot;
      <a class="font-semibold text-emerald-400 underline decoration-dotted" href="/models/">All models</a> &middot;
      <a class="font-semibold text-emerald-400 underline decoration-dotted" href="https://github.com/Devilstar333/Devilstar333.github.io">GitHub</a> &middot;
      <a class="font-semibold text-emerald-400 underline decoration-dotted" href="https://ko-fi.com/erc333" target="_blank" rel="noopener noreferrer">Support on Ko-fi &#9749;</a>
    </p>
  </div>
</footer>
</body>
</html>
'@

function Write-Utf8([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}
function Amz([string]$q) { return 'https://www.amazon.com.br/s?k=' + [Uri]::EscapeDataString($q) + '&tag=' + $tag }
$BTN = 'class="inline-flex items-center gap-1 rounded-lg bg-emerald-500 px-3 py-1.5 text-xs font-bold text-slate-950 transition hover:bg-emerald-400"'

$written = @()
$indexRows = ''

foreach ($m in $models) {
  $params = [double]$m.params
  $ctx = [int]$m.ctx
  $rows = ''
  $info = @{}

  foreach ($q in $quants) {
    $total = Get-Total $params $q.bits $ctx
    $tier = Get-Tier ($total + $vramReserve)
    $info[$q.id] = @{ total = $total; tier = $tier }
    $qnote = ''
    if ($q.note) { $qnote = ' <span class="text-xs text-slate-500">(' + $q.note + ')</span>' }
    $tierTxt = '&mdash;'
    if ($tier) { $tierTxt = 'a ' + $tier + ' GB GPU' }
    $rows += '          <tr><td class="px-4 py-2.5 font-semibold">' + $q.label + $qnote + '</td>' +
             '<td class="px-4 py-2.5 text-right font-mono">' + (Fmt $total) + ' GB</td>' +
             '<td class="px-4 py-2.5">' + $tierTxt + '</td>' +
             '<td class="px-4 py-2.5 text-right"><a class="text-xs font-semibold text-emerald-400 hover:underline" href="/?params=' + $params + '&amp;quant=' + $q.id + '&amp;ctx=' + $ctx + '">test</a></td></tr>' + [Environment]::NewLine
  }

  $q4 = $info['q4_k_m']; $q8 = $info['q8_0']; $fp = $info['fp16']
  $below = @($tiers | Where-Object { $_ -lt $q4.tier })
  $smaller = $null
  if ($below.Count -gt 0) { $smaller = $below[$below.Count - 1] }

  $moeNote = ''
  if ($m.kind -eq 'moe') {
    $moeNote = ' It is a mixture-of-experts model: only a fraction of the parameters compute per token, so it feels much faster than a dense model of the same size — but every expert still has to sit in memory, which is why the table counts the full parameter count.'
  }
  $short = 'At <strong>Q4_K_M</strong> (the quantization most people run) ' + $m.name + ' needs about <strong>' + (Fmt $q4.total) + ' GB</strong> of memory at a ' + $ctx + '-token context, so you want a <strong>' + $q4.tier + ' GB GPU</strong> to keep it entirely on the GPU.' + $moeNote

  $q4Ctx4k = Get-Total $params 4.5 4096
  $freed = [Math]::Round([Math]::Abs($q4.total - $q4Ctx4k), 1)
  $offload = ''
  if ($smaller) {
    $vramUsed = [Math]::Round($smaller - $vramReserve, 1)
    $ramUsed = [Math]::Round($q4.total - $vramUsed, 1)
    $offload = 'On a ' + $smaller + ' GB card it does not fit: roughly <strong>' + (Fmt $vramUsed) + ' GB</strong> stay in VRAM and <strong>' + (Fmt $ramUsed) + ' GB</strong> spill to system RAM. Offload works, but generation slows down several times, because system RAM bandwidth is far below GPU bandwidth. Dropping the context to 4,096 tokens frees about ' + (Fmt $freed) + ' GB.'
  } else {
    $offload = 'This is a small model: even modest GPUs hold it entirely in VRAM, which is the fastest configuration.'
  }
  $amzRam = ''
  if ($smaller) { $amzRam = '<a href="' + (Amz 'memoria ddr5 64gb') + '" target="_blank" rel="sponsored nofollow noopener noreferrer" ' + $BTN + '>DDR5 RAM kits &nearr;</a>' }
  $extra = ''
  if ($smaller) { $extra = ', plus RAM if you plan to offload' }
  $amazon = '<div class="mt-5 rounded-2xl border border-white/10 bg-white/[0.03] p-5">' +
    '<h3 class="text-sm font-bold uppercase tracking-wider text-slate-400">Shopping for a card?</h3>' +
    '<p class="mt-2 text-sm text-slate-300">Current listings for the VRAM tier that fits ' + $m.name + ' 100% at Q4_K_M' + $extra + ':</p>' +
    '<div class="mt-3 flex flex-wrap gap-2">' +
    '<a href="' + (Amz ('placa de video ' + $q4.tier + 'gb')) + '" target="_blank" rel="sponsored nofollow noopener noreferrer" ' + $BTN + '>GPUs with ' + $q4.tier + ' GB &nearr;</a>' + $amzRam +
    '</div>' +
    '<p class="mt-3 text-[11px] leading-relaxed text-slate-400">As an Amazon Associate I earn from qualifying purchases. It costs you nothing extra and helps keep this site free.</p></div>'

  $f1 = 'About ' + (Fmt $q4.total) + ' GB at a ' + $ctx + ' token context, which means a ' + $q4.tier + ' GB GPU to run it entirely on the GPU (the display reserve is already discounted).'
  $q2 = 'Does ' + $m.name + ' fit in VRAM?'
  $f2 = 'Yes. It is small enough that any recent GPU holds it entirely in VRAM, which is the fastest setup.'
  if ($smaller) {
    $q2 = 'Can ' + $m.name + ' run on a ' + $smaller + ' GB GPU?'
    $f2 = 'Not entirely. About ' + (Fmt $vramUsed) + ' GB fit in VRAM and ' + (Fmt $ramUsed) + ' GB go to system RAM, which slows generation down several times. It runs, but the experience is much worse.'
  }
  $f3 = (Fmt $q8.total) + ' GB for Q8_0 (a ' + $q8.tier + ' GB card) and ' + (Fmt $fp.total) + ' GB for FP16 (a ' + $fp.tier + ' GB card), both at the same ' + $ctx + ' token context.'

  $Q = @('How much VRAM does ' + $m.name + ' need at Q4_K_M?', $q2, 'How much memory do Q8_0 and FP16 need?')
  $A = @($f1, $f2, $f3)

  $nl = [Environment]::NewLine
  $faqHtml = '  <section class="mt-10">' + $nl + '    <h2 class="text-xl font-extrabold sm:text-2xl">Frequently asked questions</h2>' + $nl + '    <div class="mt-5 space-y-5">' + $nl
  $ld = '{"@context":"https://schema.org","@type":"FAQPage","mainEntity":['
  for ($i = 0; $i -lt $Q.Count; $i++) {
    $faqHtml += '      <div><h3 class="font-bold">' + $Q[$i] + '</h3><p class="mt-1.5 text-sm leading-relaxed text-slate-300">' + $A[$i] + '</p></div>' + $nl
    $ld += '{"@type":"Question","name":"' + $Q[$i] + '","acceptedAnswer":{"@type":"Answer","text":"' + $A[$i].Replace('"', '') + '"}}'
    if ($i -lt ($Q.Count - 1)) { $ld += ',' }
  }
  $ld += ']}'
  $faqHtml += '    </div>' + $nl + '  </section>' + $nl

  $related = (($models | Where-Object { $_.slug -ne $m.slug } | ForEach-Object { '<a class="font-semibold text-emerald-400 underline decoration-dotted" href="/models/' + $_.slug + '/">' + $_.name + '</a>' }) -join ' &middot; ')

  $canon = $base + '/models/' + $m.slug + '/'
  $title = $m.name + ' VRAM requirements: how much memory do you need?'
  $desc = 'How much VRAM ' + $m.name + ' needs: ' + (Fmt $q4.total) + ' GB at Q4_K_M with a ' + $ctx + ' token context, and which GPU tier runs it 100% on the GPU.'
  $sub = $m.family + ' &middot; ' + $params + 'B total parameters. Q4_K_M is the most used quantization; FP16 is the unquantized original.'

  $html = $TPL_TOP + $TPL_BOTTOM
  $html = $html.Replace('{{TITLE}}', $title).Replace('{{DESC}}', $desc).Replace('{{CANON}}', $canon).Replace('{{JSONLD}}', $ld)
  $html = $html.Replace('{{H1}}', 'How much VRAM does ' + $m.name + ' need?').Replace('{{BLURB}}', $m.blurb)
  $html = $html.Replace('{{CTX}}', [string]$ctx).Replace('{{RESERVE}}', $reserveTxt).Replace('{{ROWS}}', $rows)
  $html = $html.Replace('{{SUBTITLE}}', $sub).Replace('{{SHORT}}', $short).Replace('{{OFFLOAD}}', $offload)
  $html = $html.Replace('{{AMAZON}}', $amazon).Replace('{{FAQ}}', $faqHtml).Replace('{{RELATED}}', $related)
  $html = $html.Replace('{{NAME}}', $m.name).Replace('{{PARAMS}}', [string]$params)

  Write-Utf8 (Join-Path $root ('models\' + $m.slug + '\index.html')) $html
  $written += $canon
  $indexRows += '          <tr><td class="px-4 py-2.5 font-semibold"><a class="text-emerald-400 hover:underline" href="/models/' + $m.slug + '/">' + $m.name + '</a></td>' +
                '<td class="px-4 py-2.5 text-right font-mono">' + $params + ' B</td>' +
                '<td class="px-4 py-2.5 text-right font-mono">' + (Fmt $q4.total) + ' GB</td>' +
                '<td class="px-4 py-2.5">' + $q4.tier + ' GB GPU</td></tr>' + $nl
  Write-Host ('gerado: models/' + $m.slug + '/  ->  Q4_K_M ' + (Fmt $q4.total) + ' GB, cabe 100% numa GPU de ' + $q4.tier + ' GB')
}
# ---------- pagina indice /models/ (reusa o template com cabecalho trocado) ----------
$amzIdx = '<div class="mt-5 rounded-2xl border border-white/10 bg-white/[0.03] p-5"><h3 class="text-sm font-bold uppercase tracking-wider text-slate-400">Shopping for a card?</h3><p class="mt-2 text-sm text-slate-300">Current listings by VRAM tier:</p><div class="mt-3 flex flex-wrap gap-2">' +
  '<a href="' + (Amz 'placa de video 16gb') + '" target="_blank" rel="sponsored nofollow noopener noreferrer" ' + $BTN + '>16 GB &nearr;</a>' +
  '<a href="' + (Amz 'placa de video 24gb') + '" target="_blank" rel="sponsored nofollow noopener noreferrer" ' + $BTN + '>24 GB &nearr;</a>' +
  '<a href="' + (Amz 'placa de video 32gb') + '" target="_blank" rel="sponsored nofollow noopener noreferrer" ' + $BTN + '>32 GB &nearr;</a>' +
  '<a href="' + (Amz 'memoria ddr5 64gb') + '" target="_blank" rel="sponsored nofollow noopener noreferrer" ' + $BTN + '>DDR5 RAM &nearr;</a>' +
  '</div><p class="mt-3 text-[11px] leading-relaxed text-slate-400">As an Amazon Associate I earn from qualifying purchases. It costs you nothing extra and helps keep this site free.</p></div>'

$idx = $TPL_TOP + $TPL_BOTTOM
$idx = $idx.Replace('{{TITLE}}', 'VRAM requirements by model: how much memory each local LLM needs')
$idx = $idx.Replace('{{DESC}}', 'How much VRAM popular local models need at Q4_K_M, Q6_K, Q8_0 and FP16, and which GPU tier runs each one entirely on the GPU.')
$idx = $idx.Replace('{{CANON}}', ($base + '/models/')).Replace('{{JSONLD}}', '{"@context":"https://schema.org","@type":"CollectionPage","name":"Local LLM VRAM requirements by model","url":"' + $base + '/models/"}')
$idx = $idx.Replace('{{H1}}', 'How much VRAM does each local model need?')
$idx = $idx.Replace('{{BLURB}}', 'One page per model: the memory each quantization needs at the model&rsquo;s context length, the cheapest GPU tier that holds it entirely in VRAM, and what to expect when it does not fit.')
$idx = $idx.Replace('{{CTX}}', '8192').Replace('{{RESERVE}}', '0.75')
$idx = $idx.Replace('{{ROWS}}', $indexRows)
$idx = $idx.Replace('{{SUBTITLE}}', 'Q4_K_M column = total memory at an 8k context, including runtime overhead and KV cache. The last column is the smallest standard VRAM tier that runs the model 100% on the GPU.')
$idx = $idx.Replace('{{SHORT}}', 'Pick the model you actually want to run. Each page lists Q4_K_M, Q6_K, Q8_0 and FP16 with the same formula the <a class="font-semibold text-emerald-400 underline decoration-dotted" href="/">calculator</a> uses, so the numbers always agree.')
$idx = $idx.Replace('{{OFFLOAD}}', 'If your GPU is smaller than the tier listed, expect an offload split between VRAM and system RAM — it still runs, but several times slower. Generic sizes (1.5B to 405B) are in the <a class="font-semibold text-emerald-400 underline decoration-dotted" href="/vram-requirements/">full VRAM table</a>.')
$idx = $idx.Replace('{{AMAZON}}', $amzIdx).Replace('{{FAQ}}', '')
$idx = $idx.Replace('{{RELATED}}', (($models | ForEach-Object { '<a class="font-semibold text-emerald-400 underline decoration-dotted" href="/models/' + $_.slug + '/">' + $_.name + '</a>' }) -join ' &middot; '))
$idx = $idx.Replace('{{NAME}}', 'your model').Replace('{{PARAMS}}', '24').Replace('{{TITLE}}', 'VRAM requirements by model')
$idx = $idx.Replace('<th class="px-4 py-3 text-left">Quantization</th>', '<th class="px-4 py-3 text-left">Model</th>')
$idx = $idx.Replace('<th class="px-4 py-3 text-right">Total memory</th>', '<th class="px-4 py-3 text-right">Parameters</th>')
$idx = $idx.Replace('<th class="px-4 py-3 text-left">Fits 100% on the GPU with</th>', '<th class="px-4 py-3 text-left">Q4_K_M memory</th>')
$idx = $idx.Replace('<th class="px-4 py-3 text-right">Check yours</th>', '<th class="px-4 py-3 text-right">Runs 100% with</th>')
$idx = $idx.Replace('<h2 class="text-xl font-extrabold sm:text-2xl">Memory needed at 8192 context</h2>', '<h2 class="text-xl font-extrabold sm:text-2xl">All models</h2>')
Write-Utf8 (Join-Path $root 'models\index.html') $idx
$written += ($base + '/models/')

# ---------- sitemap ----------
$urls = @()
$urls += @{ loc = ($base + '/'); pri = '1.0'; freq = 'monthly' }
$urls += @{ loc = ($base + '/vram-requirements/'); pri = '0.9'; freq = 'monthly' }
$urls += @{ loc = ($base + '/models/'); pri = '0.9'; freq = 'weekly' }
foreach ($m in $models) { $urls += @{ loc = ($base + '/models/' + $m.slug + '/'); pri = '0.8'; freq = 'monthly' } }

$sm = '<?xml version="1.0" encoding="UTF-8"?>' + $nl + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">' + $nl
foreach ($u in $urls) {
  $sm += '  <url>' + $nl + '    <loc>' + $u.loc + '</loc>' + $nl + '    <lastmod>' + $today + '</lastmod>' + $nl +
         '    <changefreq>' + $u.freq + '</changefreq>' + $nl + '    <priority>' + $u.pri + '</priority>' + $nl
  if ($u.loc -eq ($base + '/')) {
    $sm += '    <xhtml:link rel="alternate" hreflang="en" href="' + $base + '/"/>' + $nl
    $sm += '    <xhtml:link rel="alternate" hreflang="pt" href="' + $base + '/?lang=pt"/>' + $nl
    $sm += '    <xhtml:link rel="alternate" hreflang="x-default" href="' + $base + '/"/>' + $nl
  }
  $sm += '  </url>' + $nl
}
$sm += '</urlset>' + $nl
Write-Utf8 (Join-Path $root 'sitemap.xml') $sm

Write-Host ''
Write-Host ('OK: ' + $models.Count + ' paginas de modelo + /models/ + sitemap com ' + $urls.Count + ' URLs')
