/**
 * Shared formatting for the Business Health components. Apex sends raw numbers plus a
 * format name (currency | percent | ratio | months | days | hours | score | number);
 * percents arrive as 0-100, never 0-1.
 */
const USD = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
const USD_COMPACT = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    notation: 'compact',
    maximumFractionDigits: 1
});
const NUM = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 });
const NUM0 = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });
const DATE = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });

export function isBlank(v) {
    return v === null || v === undefined || v === '' || (typeof v === 'number' && Number.isNaN(v));
}

/**
 * @param {number} v
 * @param {string} format
 * @param {boolean} compact abbreviate large currency (tiles, axes)
 */
export function formatValue(v, format, compact = false) {
    if (isBlank(v)) {
        return '—';
    }
    const n = Number(v);
    switch (format) {
        case 'currency':
            return compact && Math.abs(n) >= 10000 ? USD_COMPACT.format(n) : USD.format(n);
        case 'percent':
            return `${NUM.format(n)}%`;
        case 'ratio':
            return `${n.toFixed(2)}x`;
        case 'months':
            return `${n.toFixed(1)} mo`;
        case 'days':
            return `${NUM0.format(n)} days`;
        case 'hours':
            return `${NUM0.format(n)} hrs`;
        case 'score':
            return n.toFixed(2);
        default:
            return Math.abs(n) >= 100 ? NUM0.format(n) : NUM.format(n);
    }
}

/** Axis tick labels: always compact, never units that crowd the axis. */
export function formatAxis(v, format) {
    if (format === 'currency') {
        return Math.abs(v) >= 1000 ? USD_COMPACT.format(v) : USD.format(v);
    }
    if (format === 'percent') {
        return `${NUM0.format(v)}%`;
    }
    if (format === 'ratio') {
        return `${Number(v).toFixed(1)}x`;
    }
    return Math.abs(v) >= 1000 ? new Intl.NumberFormat('en-US', { notation: 'compact' }).format(v) : NUM.format(v);
}

/** Apex Dates arrive as 'YYYY-MM-DD'; format without shifting timezones. */
export function formatDate(v) {
    if (isBlank(v)) {
        return '—';
    }
    const d = new Date(`${String(v).substring(0, 10)}T00:00:00Z`);
    return Number.isNaN(d.getTime()) ? String(v) : DATE.format(d);
}

export const STATUS_LABEL = {
    good: 'On target',
    warn: 'Watch',
    bad: 'Off target',
    neutral: 'No target',
    info: 'Note'
};

/** Status glyphs so state is never communicated by color alone. */
export const STATUS_ICON = {
    good: '✓',
    warn: '!',
    bad: '✕',
    neutral: '·',
    info: 'i'
};

/** "Nice" axis maximum and tick step for a data maximum. */
export function niceScale(min, max, ticks = 4) {
    const lo = Math.min(0, min);
    const hi = max <= lo ? lo + 1 : max;
    const rawStep = (hi - lo) / ticks;
    const mag = 10 ** Math.floor(Math.log10(rawStep));
    const norm = rawStep / mag;
    const step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10) * mag;
    const niceMin = Math.floor(lo / step) * step;
    const niceMax = Math.ceil(hi / step) * step;
    const values = [];
    for (let t = niceMin; t <= niceMax + step / 2; t += step) {
        values.push(Math.round(t * 1e6) / 1e6);
    }
    return { min: niceMin, max: niceMax, ticks: values };
}

const MODEL_NAMES = {
    sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet: 'Claude Sonnet 4.5',
    sfdc_ai__DefaultBedrockAnthropicClaude45Haiku: 'Claude Haiku 4.5',
    sfdc_ai__DefaultBedrockAnthropicClaude4Sonnet: 'Claude Sonnet 4',
    sfdc_ai__DefaultBedrockAnthropicClaude37Sonnet: 'Claude Sonnet 3.7',
    sfdc_ai__DefaultGPT41: 'GPT-4.1',
    sfdc_ai__DefaultOpenAIGPT4OmniMini: 'GPT-4o mini',
    sfdc_ai__DefaultVertexAIGemini25Flash001: 'Gemini 2.5 Flash'
};

export function modelLabel(model) {
    return MODEL_NAMES[model] || model || 'Einstein';
}
