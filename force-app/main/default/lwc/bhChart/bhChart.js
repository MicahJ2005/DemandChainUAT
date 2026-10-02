import { LightningElement, api } from 'lwc';
import { formatValue, formatAxis, niceScale, isBlank } from 'c/bhFormat';

// Categorical series colors in fixed order (validated set: blue, orange, aqua; yellow
// only as a 4th). Status colors (good/warn/bad) are reserved and never used here.
const SERIES_COLORS = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100'];
const W = 640;
const VH = 260;
const M = { top: 14, right: 16, bottom: 34, left: 58 };
const BAR_MAX = 24;
const GAP = 2;
const H_LABEL_W = 170;
const H_BAR = 14;

function roundedBarPath(x, yTop, w, yBase, r) {
    // Vertical bar, rounded at the data end only (square at the baseline).
    const h = yBase - yTop;
    if (Math.abs(h) < 0.5) {
        return '';
    }
    if (h < 0) {
        const rr = Math.min(r, w / 2, -h);
        return `M${x},${yBase} V${yTop - rr} Q${x},${yTop} ${x + rr},${yTop} H${x + w - rr} Q${x + w},${yTop} ${x + w},${yTop - rr} V${yBase} Z`;
    }
    const rr = Math.min(r, w / 2, h);
    return `M${x},${yBase} V${yTop + rr} Q${x},${yTop} ${x + rr},${yTop} H${x + w - rr} Q${x + w},${yTop} ${x + w},${yTop + rr} V${yBase} Z`;
}

function roundedHBarPath(xBase, y, xEnd, h, r) {
    const w = xEnd - xBase;
    if (Math.abs(w) < 0.5) {
        return '';
    }
    const rr = Math.min(r, h / 2, Math.abs(w));
    if (w < 0) {
        return `M${xBase},${y} H${xEnd + rr} Q${xEnd},${y} ${xEnd},${y + rr} V${y + h - rr} Q${xEnd},${y + h} ${xEnd + rr},${y + h} H${xBase} Z`;
    }
    return `M${xBase},${y} H${xEnd - rr} Q${xEnd},${y} ${xEnd},${y + rr} V${y + h - rr} Q${xEnd},${y + h} ${xEnd - rr},${y + h} H${xBase} Z`;
}

/**
 * Dependency-free SVG chart for Business Health pages: grouped bar, line, and
 * horizontal bar forms, one y-axis, recessive gridlines, an optional target line,
 * a legend for 2+ series, hover tooltips, and a table view for accessibility.
 */
export default class BhChart extends LightningElement {
    @api chart;
    hoverIndex = null;
    showTable = false;

    get series() {
        return (this.chart && this.chart.series) || [];
    }

    get labels() {
        return (this.chart && this.chart.labels) || [];
    }

    get format() {
        return (this.chart && this.chart.format) || 'number';
    }

    get isHbar() {
        return this.chart && this.chart.type === 'hbar';
    }

    get isLine() {
        return this.chart && this.chart.type === 'line';
    }

    get hasData() {
        return this.series.some((s) => (s.values || []).some((v) => !isBlank(v) && Number(v) !== 0));
    }

    get legend() {
        if (this.series.length < 2) {
            return [];
        }
        return this.series.map((s, i) => ({
            key: s.name,
            name: s.name,
            swatchStyle: `background:${SERIES_COLORS[i % SERIES_COLORS.length]}`,
            swatchClass: this.isLine ? 'swatch swatch-line' : 'swatch'
        }));
    }

    get hasLegend() {
        return this.legend.length > 0;
    }

    get targetLegend() {
        return this.chart && !isBlank(this.chart.targetLine)
            ? `${this.chart.targetLabel || 'Target'}: ${formatValue(this.chart.targetLine, this.format)}`
            : null;
    }

    get tableToggleLabel() {
        return this.showTable ? 'View chart' : 'View as table';
    }

    toggleTable() {
        this.showTable = !this.showTable;
    }

    // ---- scales ------------------------------------------------------------------

    get valueExtent() {
        const vals = [];
        this.series.forEach((s) => (s.values || []).forEach((v) => !isBlank(v) && vals.push(Number(v))));
        if (this.chart && !isBlank(this.chart.targetLine)) {
            vals.push(Number(this.chart.targetLine));
        }
        if (!vals.length) {
            return niceScale(0, 1);
        }
        return niceScale(Math.min(...vals), Math.max(...vals));
    }

    get height() {
        if (!this.isHbar) {
            return VH;
        }
        return M.top + this.labels.length * this.rowHeight + M.bottom;
    }

    get rowHeight() {
        return this.series.length * (H_BAR + GAP) + 12;
    }

    get viewBox() {
        return `0 0 ${W} ${this.height}`;
    }

    get plot() {
        const left = this.isHbar ? H_LABEL_W : M.left;
        // Single-series horizontal bars carry direct value labels past the bar end;
        // leave room so the longest one isn't clipped.
        const right = this.isHbar && this.series.length === 1 ? W - 64 : W - M.right;
        return {
            left,
            right,
            top: M.top,
            bottom: this.height - M.bottom,
            width: right - left,
            height: this.height - M.bottom - M.top
        };
    }

    y(v) {
        const s = this.valueExtent;
        const p = this.plot;
        return p.top + p.height - ((v - s.min) / (s.max - s.min)) * p.height;
    }

    x(v) {
        const s = this.valueExtent;
        const p = this.plot;
        return p.left + ((v - s.min) / (s.max - s.min)) * p.width;
    }

    get band() {
        return this.plot.width / Math.max(1, this.labels.length);
    }

    // ---- vertical (bar / line) -------------------------------------------------------

    get gridY() {
        const p = this.plot;
        return this.valueExtent.ticks.map((t) => ({
            key: `gy${t}`,
            y: this.y(t),
            x1: p.left,
            x2: p.right,
            labelX: p.left - 8,
            labelY: this.y(t) + 4,
            label: formatAxis(t, this.format)
        }));
    }

    get xLabels() {
        const n = this.labels.length;
        const step = n > 14 ? Math.ceil(n / 10) : n > 9 ? 2 : 1;
        return this.labels.map((l, i) => ({
            key: `xl${i}`,
            x: this.plot.left + this.band * (i + 0.5),
            y: this.plot.bottom + 18,
            label: i % step === 0 || i === n - 1 ? l : ''
        }));
    }

    get bars() {
        if (this.isLine || this.isHbar) {
            return [];
        }
        const k = this.series.length;
        const barW = Math.min(BAR_MAX, (this.band * 0.72 - (k - 1) * GAP) / k);
        const groupW = k * barW + (k - 1) * GAP;
        const base = this.y(Math.max(0, this.valueExtent.min));
        const out = [];
        this.series.forEach((s, j) => {
            (s.values || []).forEach((v, i) => {
                if (isBlank(v)) {
                    return;
                }
                const x0 = this.plot.left + this.band * i + (this.band - groupW) / 2 + j * (barW + GAP);
                out.push({
                    key: `b${j}-${i}`,
                    d: roundedBarPath(x0, this.y(Number(v)), barW, base, 4),
                    fill: SERIES_COLORS[j % SERIES_COLORS.length],
                    opacity: this.hoverIndex === null || this.hoverIndex === i ? 1 : 0.45
                });
            });
        });
        return out;
    }

    get lines() {
        if (!this.isLine) {
            return [];
        }
        return this.series.map((s, j) => {
            let d = '';
            let pen = false;
            let last = null;
            (s.values || []).forEach((v, i) => {
                if (isBlank(v)) {
                    pen = false;
                    return;
                }
                const px = this.plot.left + this.band * (i + 0.5);
                const py = this.y(Number(v));
                d += `${pen ? 'L' : 'M'}${px.toFixed(1)},${py.toFixed(1)} `;
                pen = true;
                last = { x: px, y: py };
            });
            return {
                key: `l${j}`,
                d,
                stroke: SERIES_COLORS[j % SERIES_COLORS.length],
                hasEnd: !!last,
                endX: last ? last.x : 0,
                endY: last ? last.y : 0
            };
        });
    }

    get hoverMarkers() {
        if (!this.isLine || this.hoverIndex === null) {
            return [];
        }
        const i = this.hoverIndex;
        return this.series
            .map((s, j) => ({ v: (s.values || [])[i], j }))
            .filter((m) => !isBlank(m.v))
            .map((m) => ({
                key: `hm${m.j}`,
                cx: this.plot.left + this.band * (i + 0.5),
                cy: this.y(Number(m.v)),
                fill: SERIES_COLORS[m.j % SERIES_COLORS.length]
            }));
    }

    get crosshair() {
        if (!this.isLine || this.hoverIndex === null) {
            return null;
        }
        const x = this.plot.left + this.band * (this.hoverIndex + 0.5);
        return { x, y1: this.plot.top, y2: this.plot.bottom };
    }

    get hoverBands() {
        const p = this.plot;
        if (this.isHbar) {
            return this.labels.map((l, i) => ({
                key: `hb${i}`,
                index: i,
                x: 0,
                y: p.top + i * this.rowHeight,
                width: W,
                height: this.rowHeight
            }));
        }
        return this.labels.map((l, i) => ({
            key: `hb${i}`,
            index: i,
            x: p.left + this.band * i,
            y: p.top,
            width: this.band,
            height: p.height
        }));
    }

    get target() {
        if (!this.chart || isBlank(this.chart.targetLine)) {
            return null;
        }
        const t = Number(this.chart.targetLine);
        const p = this.plot;
        if (this.isHbar) {
            const x = this.x(t);
            return { x1: x, x2: x, y1: p.top - 4, y2: p.bottom, labelX: x + 4, labelY: p.top + 6, anchor: 'start', label: this.chart.targetLabel || 'Target' };
        }
        const y = this.y(t);
        return { x1: p.left, x2: p.right, y1: y, y2: y, labelX: p.right, labelY: y - 5, anchor: 'end', label: this.chart.targetLabel || 'Target' };
    }

    // ---- horizontal bars ----------------------------------------------------------------

    get gridX() {
        const p = this.plot;
        return this.valueExtent.ticks.map((t) => ({
            key: `gx${t}`,
            x: this.x(t),
            y1: p.top,
            y2: p.bottom,
            labelY: p.bottom + 16,
            label: formatAxis(t, this.format)
        }));
    }

    get hbars() {
        if (!this.isHbar) {
            return [];
        }
        const p = this.plot;
        const base = this.x(Math.max(0, this.valueExtent.min));
        const out = [];
        this.labels.forEach((l, i) => {
            this.series.forEach((s, j) => {
                const v = (s.values || [])[i];
                if (isBlank(v)) {
                    return;
                }
                const y = p.top + i * this.rowHeight + 6 + j * (H_BAR + GAP);
                const xe = this.x(Number(v));
                out.push({
                    key: `hbar${i}-${j}`,
                    d: roundedHBarPath(base, y, xe, H_BAR, 4),
                    fill: SERIES_COLORS[j % SERIES_COLORS.length],
                    opacity: this.hoverIndex === null || this.hoverIndex === i ? 1 : 0.45,
                    // Direct value labels only for single-series rows (avoids clutter).
                    showValue: this.series.length === 1,
                    valueX: Number(v) < 0 ? xe - 4 : xe + 4,
                    valueY: y + H_BAR - 3,
                    anchor: Number(v) < 0 ? 'end' : 'start',
                    valueLabel: formatValue(v, this.format, true)
                });
            });
        });
        return out;
    }

    get rowLabels() {
        const p = this.plot;
        return this.labels.map((l, i) => ({
            key: `rl${i}`,
            x: p.left - 8,
            y: p.top + i * this.rowHeight + this.rowHeight / 2 + 3,
            label: l && l.length > 26 ? `${l.substring(0, 25)}…` : l,
            full: l
        }));
    }

    // ---- hover / tooltip -------------------------------------------------------------------

    handleEnter(event) {
        this.hoverIndex = Number(event.currentTarget.dataset.index);
    }

    handleLeave() {
        this.hoverIndex = null;
    }

    get tooltip() {
        if (this.hoverIndex === null) {
            return null;
        }
        const i = this.hoverIndex;
        const rows = this.series.map((s, j) => ({
            key: `tt${j}`,
            name: s.name,
            value: formatValue((s.values || [])[i], this.format),
            swatchStyle: `background:${SERIES_COLORS[j % SERIES_COLORS.length]}`
        }));
        let leftPct;
        let topPct;
        if (this.isHbar) {
            leftPct = 55;
            topPct = ((this.plot.top + (i + 1) * this.rowHeight) / this.height) * 100;
        } else {
            leftPct = ((this.plot.left + this.band * (i + 0.5)) / W) * 100;
            topPct = 4;
        }
        const flip = leftPct > 60;
        return {
            title: this.labels[i],
            rows,
            style: `top:${topPct}%;${flip ? `right:${100 - leftPct + 2}%` : `left:${leftPct + 2}%`}`
        };
    }

    // ---- table view ----------------------------------------------------------------------

    get tableHeaders() {
        return this.series.map((s, j) => ({ key: `th${j}`, name: s.name }));
    }

    get tableRows() {
        return this.labels.map((l, i) => ({
            key: `tr${i}`,
            label: l,
            cells: this.series.map((s, j) => ({ key: `tc${i}-${j}`, value: formatValue((s.values || [])[i], this.format) }))
        }));
    }

    get ariaLabel() {
        return `${(this.chart && this.chart.title) || 'Chart'}. Use "View as table" for the values.`;
    }
}
