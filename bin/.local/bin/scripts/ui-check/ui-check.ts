// ui-check: render a page at several widths, save full-page screenshots, and
// run high-precision layout checks. Findings are candidates; confirm each on
// the screenshot before acting on it.
//
//   ui-check <url-or-file> [--widths 1280,768,375] [--storage-state FILE] [--out DIR]
//
// --storage-state: Playwright session file (cookies/localStorage) for pages
// behind a login. Browser: $CHROME, else chrome-headless-shell on PATH, else
// Playwright's own (install: bunx playwright-core install chromium-headless-shell).
import { chromium } from 'playwright-core';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

type Finding = { kind: string; detail: string; at: string[] };

const args = process.argv.slice(2);
const flag = (name: string, fallback: string) => { const i = args.indexOf(name); return i < 0 ? fallback : args.splice(i, 2)[1]; };
const widths = flag('--widths', '1280,768,375').split(',').map(Number);
const storageState = flag('--storage-state', '') || undefined;
const out = resolve(flag('--out', mkdtempSync(join(tmpdir(), 'ui-check-'))));
const target = args[0];
if (!target) { console.error('usage: ui-check <url-or-file> [--widths 1280,768,375] [--storage-state FILE] [--out DIR]'); process.exit(2); }
mkdirSync(out, { recursive: true });
const url = /^[a-z]+:\/\//i.test(target) ? target : pathToFileURL(resolve(target)).href;

// Runs in the page. Only checks that held up on a real app; no near-miss
// heuristics, which were mostly noise.
function measure(): { findings: Finding[]; tokens: Record<string, string> } {
  const out: Finding[] = [];
  const sel = (el: Element): string => {
    if (el.id) return `#${el.id}`;
    const parts: string[] = [];
    for (let e: Element | null = el; e && e !== document.body && parts.length < 4; e = e.parentElement) {
      const cls = [...e.classList].slice(0, 2).map((c) => `.${CSS.escape(c)}`).join('');
      const i = e.parentElement ? [...e.parentElement.children].indexOf(e) + 1 : 1;
      parts.unshift(`${e.tagName.toLowerCase()}${cls}:nth-child(${i})`);
    }
    return parts.join(' > ');
  };
  const add = (kind: string, detail: string, els: Element[] = []) => out.push({ kind, detail, at: els.slice(0, 3).map(sel) });
  const px = (v: number) => Math.round(v * 100) / 100;

  // Skipped: icon artwork (shapes inside <svg>) and clipped 1px boxes
  // (screen-reader-only content such as chart data tables).
  const all = [...document.body.querySelectorAll('*')];
  const clipped = all.filter((el) => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return r.width <= 1 && r.height <= 1 && (s.overflow === 'hidden' || s.clip !== 'auto' || s.clipPath !== 'none');
  });
  const visible = all.filter((el) => {
    if (el.parentElement?.closest('svg') || clipped.some((c) => c.contains(el))) return false;
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return r.width > 1 && r.height > 1 && s.visibility !== 'hidden' && s.display !== 'contents';
  });
  const rect = new Map(visible.map((el) => [el, el.getBoundingClientRect()]));
  const css = (el: Element) => getComputedStyle(el);
  const key = (el: Element) => `${el.tagName}.${el.getAttribute('class')}`;

  // Page: sideways scroll, viewport meta, broken images.
  const doc = document.documentElement;
  if (doc.scrollWidth > doc.clientWidth + 1) add('page-overflow', `page is ${doc.scrollWidth}px wide in a ${doc.clientWidth}px viewport`);
  if (!document.querySelector('meta[name="viewport"]')) add('no-viewport-meta', 'mobile browsers lay this out at ~980px and shrink it');
  for (const img of document.images) {
    if (img.loading === 'lazy' && !img.complete) continue;
    if (!img.complete || !img.naturalWidth) add('broken-image', img.getAttribute('src') ?? '(no src)', [img]);
  }

  // Content hidden inside a scroll container (tabs, tables cut off).
  for (const el of visible) {
    const s = css(el);
    if (!['auto', 'scroll', 'hidden'].includes(s.overflowX) || el === doc || el === document.body) continue;
    const hidden = el.scrollWidth - el.clientWidth;
    if (hidden > 1) add('clipped', `content is ${el.scrollWidth}px wide in a ${el.clientWidth}px box (${hidden}px hidden, overflow-x:${s.overflowX})`, [el]);
  }

  // Repeated components side by side: equal heights, and their parts line up.
  for (const parent of new Set(visible.map((el) => el.parentElement))) {
    if (!parent || parent.matches('tr')) continue;
    const kids = [...parent.children].flatMap((k) => (css(k).display === 'contents' ? [...k.children] : [k])).filter((k) => rect.has(k) && k.getAttribute('class'));
    for (const group of Object.values(Object.groupBy(kids, key))) {
      const rows = Object.values(Object.groupBy(group ?? [], (k) => Math.round(rect.get(k)!.top))).filter((r) => r && r.length > 1) as Element[][];
      for (const row of rows) {
        const spread = (v: number[]) => Math.max(...v) - Math.min(...v);
        const heights = row.map((k) => rect.get(k)!.height);
        if (heights[0] >= 48 && spread(heights) > 0.5) add('unequal-heights', `${row.length} side-by-side items differ in height by ${px(spread(heights))}px`, row);
        const path = (root: Element, el: Element) => { const p: number[] = []; for (let e: Element = el; e !== root; e = e.parentElement!) p.unshift([...e.parentElement!.children].indexOf(e)); return p.join('/'); };
        const parts = new Map<string, Element[]>();
        for (const k of row) for (const d of k.querySelectorAll('*')) if (rect.has(d)) parts.set(path(k, d), [...(parts.get(path(k, d)) ?? []), d]);
        for (const ds of parts.values()) {
          if (ds.length < 2) continue;
          const tops = spread(ds.map((d) => rect.get(d)!.top));
          if (tops > 0.5) add('parts-misaligned', `same part sits at different heights across ${ds.length} side-by-side items (spread ${px(tops)}px)`, ds);
        }
      }
    }
  }

  // Lone item in the last row of a grid of repeated components.
  for (const grid of visible.filter((el) => css(el).display.endsWith('grid') && !el.matches('dl') && !el.closest('form'))) {
    const cols = css(grid).gridTemplateColumns.replace(/\[[^\]]*\]/g, ' ').trim().split(/\s+/).length;
    const kids = [...grid.children].flatMap((k) => (css(k).display === 'contents' ? [...k.children] : [k])).filter((k) => rect.has(k));
    if (kids.some((k) => css(k).gridColumnStart !== 'auto' || css(k).gridColumnEnd !== 'auto')) continue;
    if (new Set(kids.map(key)).size !== 1) continue;
    const alone = kids.length % cols;
    if (cols > 1 && kids.length > cols && alone && alone <= cols / 2) add('orphan-row', `${kids.length} items in ${cols} columns leaves ${alone} alone in the last row`, [grid]);
  }

  // Inner radius should be outer radius minus the gap between them.
  for (const el of visible) {
    const parent = el.parentElement;
    if (!parent || !rect.has(parent)) continue;
    const radius = (e: Element) => { const v = css(e).borderTopLeftRadius; return /^[\d.]+px$/.test(v) ? parseFloat(v) : 0; };
    const inner = radius(el);
    const outer = radius(parent);
    const gap = rect.get(el)!.left - rect.get(parent)!.left;
    if (inner > 0 && outer > 0 && gap > 0 && gap < outer && Math.abs(inner - (outer - gap)) > 1) add('nested-radius', `inner ${inner}px inside outer ${outer}px with ${px(gap)}px gap; expected ~${px(outer - gap)}px`, [el]);
  }

  // Quantities in table cells: right-aligned, tabular figures. Phone numbers are identifiers.
  const numeric = /^[\s$€£¥+\-−(]*\d[\d,.\s]*%?\)?$/;
  const phone = /^\s*\+\d[\d\s()-]{6,}$/;
  for (const cell of visible.filter((el) => el.matches('td') && numeric.test(el.textContent ?? '') && !phone.test(el.textContent ?? ''))) {
    const s = css(cell);
    const issues = [!['right', 'end'].includes(s.textAlign) && `text-align:${s.textAlign}`, !s.fontVariantNumeric.includes('tabular-nums') && 'no tabular-nums'].filter(Boolean);
    if (issues.length) add('numeric-cell', issues.join(', '), [cell]);
  }

  // Small or transformed elements on half pixels render soft at 1x.
  for (const [el, r] of rect) {
    const moved = css(el).transform !== 'none';
    if ((moved || (r.width <= 48 && r.height <= 48 && el.matches('svg, img, button'))) && (r.left % 1 || r.top % 1)) add('subpixel', `at (${px(r.left)}, ${px(r.top)})`, [el]);
  }

  // Value inventories: near-duplicates here (15px next to 16px) are drift.
  const tally = (prop: string) => {
    const m = new Map<string, number>();
    for (const el of visible) for (const v of (css(el) as any)[prop].split(' ')) if (v && v !== '0px' && v !== 'normal' && v !== 'auto') m.set(v, (m.get(v) ?? 0) + 1);
    return [...m].sort((a, b) => parseFloat(a[0]) - parseFloat(b[0])).map(([v, n]) => `${v}×${n}`).join(' ');
  };
  const tokens = { padding: tally('padding'), gap: tally('gap'), radius: tally('borderRadius'), fontSize: tally('fontSize') };
  return { findings: out, tokens };
}

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? Bun.which('chrome-headless-shell') ?? undefined });
try {
  const report: Record<number, unknown> = {};
  for (const width of widths) {
    const context = await browser.newContext({ viewport: { width, height: 900 }, deviceScaleFactor: 1, isMobile: width < 600, storageState });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    const { findings, tokens } = await page.evaluate(measure);
    const screenshot = join(out, `shot-${width}.png`);
    await page.screenshot({ path: screenshot, fullPage: true });
    report[width] = { screenshot, findings, tokens };
    console.log(`\n== ${width}px  ${screenshot}`);
    const byKind = Object.groupBy(findings, (f) => f.kind);
    for (const [kind, list] of Object.entries(byKind)) {
      for (const f of list!.slice(0, 5)) console.log(`  ${kind}: ${f.detail}${f.at.length ? `  @ ${f.at.join(' | ')}` : ''}`);
      if (list!.length > 5) console.log(`  ${kind}: … ${list!.length - 5} more in report.json`);
    }
    if (!findings.length) console.log('  no findings');
    for (const [prop, values] of Object.entries(tokens)) console.log(`  values ${prop}: ${values}`);
    await context.close();
  }
  writeFileSync(join(out, 'report.json'), JSON.stringify({ url, widths: report }, null, 2));
  console.log(`\nreport: ${join(out, 'report.json')}`);
} catch (err) {
  console.error(`ui-check: ${(err as Error).message.split('\n')[0]}`);
  process.exitCode = 1;
} finally {
  await browser.close();
}
