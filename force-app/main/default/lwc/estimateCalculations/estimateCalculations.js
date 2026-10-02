/**
 * Pure calculation helpers shared by the estimate builder and its child
 * components. Ported from the original standalone HTML estimator's inline
 * <script> math so every component computes totals/margins the same way.
 */

const PHASE_KEYS = ['planning', 'discovery', 'pb', 'deploy', 'wrapup'];

const PHASE_HOUR_FIELDS = {
    planning: 'Planning_Hours__c',
    discovery: 'Discovery_Hours__c',
    pb: 'PB_Hours__c',
    deploy: 'Deploy_Hours__c',
    wrapup: 'Wrapup_Hours__c'
};

const PHASE_COLORS = {
    planning: '#912121',
    discovery: '#00B0F0',
    pb: '#002060',
    deploy: '#595959',
    wrapup: '#B0AEAC'
};

const PHASE_LABELS = {
    planning: 'Planning',
    discovery: 'Discovery',
    pb: 'Plan & Build',
    deploy: 'Deploy',
    wrapup: 'Wrap-up'
};

export const RATE_CLASSES = [
    'Chief Architect/MVP',
    'Solutions Architect',
    'Technical Architect',
    'Senior Consultant',
    'Consultant',
    'Senior Administrator',
    'Administrator'
];

export const DELIVERABLE_PHASES = ['Planning', 'Discovery', 'P&B', 'Deploy', 'Wrap-up'];

export const SLA_TIERS = ['Standard', 'Priority', 'Expedited'];

export function nz(value) {
    return value === null || value === undefined || value === '' ? 0 : Number(value);
}

export function lineTotalHours(line) {
    if (line.Line_Type__c === 'Team Resource') {
        return PHASE_KEYS.reduce((sum, p) => sum + nz(line[PHASE_HOUR_FIELDS[p]]), 0);
    }
    if (line.Line_Type__c === 'MS Tier') {
        return nz(line.Hours_Per_Week__c);
    }
    return nz(line.Total_Hours__c);
}

export function lineCost(line) {
    return lineTotalHours(line) * nz(line.Cost_Per_Hour__c);
}

export function linePrice(line) {
    if (line.Line_Type__c === 'Fixed Deliverable' && line.Fixed_Price__c !== null && line.Fixed_Price__c !== undefined && line.Fixed_Price__c !== '') {
        return nz(line.Fixed_Price__c);
    }
    return lineTotalHours(line) * nz(line.Price_Per_Hour__c);
}

export function marginPercent(price, cost) {
    return price === 0 ? 0 : ((price - cost) / price) * 100;
}

export function recalcLine(line) {
    const totalHours = lineTotalHours(line);
    const cost = lineCost(line);
    const price = linePrice(line);
    return {
        ...line,
        Total_Hours__c: totalHours,
        Line_Cost__c: cost,
        Line_Price__c: price,
        Margin__c: marginPercent(price, cost)
    };
}

export function sumField(lines, field, includedOnly) {
    return (lines || [])
        .filter((l) => !includedOnly || l.Include_In_Rollup__c !== false)
        .reduce((sum, l) => sum + nz(l[field]), 0);
}

export function phaseWeeks(header) {
    return {
        planning: nz(header.Planning_Weeks__c),
        discovery: nz(header.Discovery_Weeks__c),
        pb: nz(header.PB_Sprints__c) * nz(header.Sprint_Length_Weeks__c),
        deploy: nz(header.Deploy_Weeks__c),
        wrapup: nz(header.Wrapup_Weeks__c)
    };
}

export function totalWeeksForHeader(header) {
    const weeks = phaseWeeks(header);
    return Math.max(1, Math.round(Object.values(weeks).reduce((a, b) => a + b, 0)));
}

export function phaseSegments(header) {
    const weeks = phaseWeeks(header);
    const total = Object.values(weeks).reduce((a, b) => a + b, 0) || 1;
    let cursor = 0;
    return PHASE_KEYS.map((p) => {
        const w = weeks[p];
        const widthPercent = (w / total) * 100;
        const seg = {
            key: p,
            label: PHASE_LABELS[p],
            color: PHASE_COLORS[p],
            weeks: w,
            widthPercent,
            xPercent: cursor,
            style: `background-color:${PHASE_COLORS[p]}; width:${widthPercent}%;`
        };
        cursor += widthPercent;
        return seg;
    });
}

/**
 * Maps a resource's Weekly_Hours_JSON__c ({weekIndex: hours}) into phase-hour
 * totals so weekly-grid entry always rolls up into the same fields the
 * by-phase entry mode uses.
 */
export function weeklyJsonToPhaseHours(weeklyHoursJson, header) {
    const weeks = phaseWeeks(header);
    const boundaries = [];
    let cursor = 0;
    PHASE_KEYS.forEach((p) => {
        const start = cursor + 1;
        cursor += weeks[p];
        boundaries.push({ phase: p, start, end: cursor });
    });

    const totals = { planning: 0, discovery: 0, pb: 0, deploy: 0, wrapup: 0 };
    let map = {};
    try {
        map = weeklyHoursJson ? JSON.parse(weeklyHoursJson) : {};
    } catch (e) {
        map = {};
    }
    Object.keys(map).forEach((weekIndexStr) => {
        const weekIndex = Number(weekIndexStr);
        const hours = nz(map[weekIndexStr]);
        const boundary = boundaries.find((b) => weekIndex >= b.start && weekIndex <= b.end);
        if (boundary) {
            totals[boundary.phase] += hours;
        }
    });

    return {
        Planning_Hours__c: totals.planning,
        Discovery_Hours__c: totals.discovery,
        PB_Hours__c: totals.pb,
        Deploy_Hours__c: totals.deploy,
        Wrapup_Hours__c: totals.wrapup
    };
}

export function parseWeeklyHours(weeklyHoursJson) {
    try {
        return weeklyHoursJson ? JSON.parse(weeklyHoursJson) : {};
    } catch (e) {
        return {};
    }
}

export function formatCurrency(value) {
    const num = nz(value);
    return num.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
}

export function formatPercent(value) {
    return `${nz(value).toFixed(1)}%`;
}

let tempIdCounter = 0;
export function tempId(prefix) {
    tempIdCounter += 1;
    return `${prefix || 'tmp'}_${tempIdCounter}_${Math.floor(nz(Date.now ? Date.now() : 0))}`;
}
