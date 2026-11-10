# Layouts

Five reference pages in `examples/`. They are complete, rendered HTML (data and chart configs inlined), so open the one closest to the request and copy its structure. They're in English; when the user writes in another language, keep the structure and follow the Languages section of `SKILL.md` for `lang`, `dir`, fonts and number formatting.

| File | Use for | Width | Key blocks |
|---|---|---|---|
| `essay.html` | essays, explanations, memos, anything that is mostly prose | `max-w-3xl` | `prose` article, blockquote, ordered list |
| `report.html` | research or report with data over time | `max-w-3xl` | KPI strip, line chart, bar chart with highlighted last bar, full data table with colored deltas |
| `dashboard.html` | dashboards, market or metrics summaries | `max-w-5xl` | 4-up KPI grid, long line chart, two side-by-side tables, diverging bar chart (green/red) |
| `comparison.html` | decisions, plan/vendor/option comparisons | `max-w-3xl` | recommendation callout, feature matrix with highlighted column, 3-column pros/cons |
| `incident.html` | briefs, incident reports, status updates, changelogs | `max-w-3xl` | key-value header, vertical timeline, action list with status |

## Building blocks

Section heading (mono eyebrow style, used instead of big h2s):

```html
<h2 class="mt-14 mb-4 font-mono text-xs uppercase tracking-widest text-neutral-500">Section</h2>
```

KPI strip:

```html
<div class="grid grid-cols-3 divide-x divide-neutral-200 border-y border-neutral-200">
  <div class="px-4 py-6 first:ps-0"><p class="text-3xl font-semibold tabular-nums">−29%</p><p class="mt-1 text-sm text-neutral-500">label</p></div>
</div>
```

KPI grid with hairline gaps (dashboards):

```html
<div class="grid grid-cols-2 gap-px bg-neutral-200 border border-neutral-200 md:grid-cols-4">
  <div class="bg-white p-5"><p class="font-mono text-xs uppercase tracking-wider text-neutral-500">Label</p><p class="mt-2 text-2xl font-semibold tabular-nums">128,400</p><p class="mt-1 text-sm text-emerald-600">+0.84%</p></div>
</div>
```

Table:

```html
<table class="w-full text-sm tabular-nums">
  <thead class="text-start text-neutral-500"><tr class="border-b border-neutral-200"><th class="py-2 font-medium">Name</th><th class="py-2 text-end font-medium">Value</th></tr></thead>
  <tbody class="divide-y divide-neutral-100"><tr><td class="py-2">A</td><td class="py-2 text-end">1,234</td></tr></tbody>
</table>
```

Callout:

```html
<div class="border-s-2 border-neutral-900 ps-5"><p class="font-mono text-xs uppercase tracking-widest text-neutral-500">Recommendation</p><p class="mt-2 text-lg">…</p></div>
```

Line chart:

```html
<canvas id="c" height="110"></canvas>
<script>addEventListener('load', () => new Chart(c, { type: 'line',
  data: { labels, datasets: [{ data, borderColor: '#171717', borderWidth: 1.5, pointRadius: 0, tension: .3, fill: true, backgroundColor: 'rgba(23,23,23,.04)' }] },
  options: { plugins: { legend: { display: false } }, scales: { x: { grid: { display: false } } } } }));</script>
```

For multiple series, use `#171717`, `#a3a3a3` and `#d4d4d4` and keep the legend.
