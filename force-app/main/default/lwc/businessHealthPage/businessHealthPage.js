import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPage from '@salesforce/apex/BusinessHealthController.getPage';
import getFilterOptions from '@salesforce/apex/BusinessHealthController.getFilterOptions';
import { formatValue, formatDate, isBlank, STATUS_LABEL, STATUS_ICON } from 'c/bhFormat';

const COLLAPSED_ROWS = 10;
const SPARK_W = 120;
const SPARK_H = 30;
const NUMERIC_TYPES = new Set(['currency', 'percent', 'number', 'ratio', 'hours', 'score']);

/**
 * Renders any Business Health page (Leadership, Sales & Pipeline, Financial,
 * Utilization & Capacity, Delivery, Client Portfolio, People) from the generic page
 * model BusinessHealthController returns: KPI tiles, AI Advisor, signals, charts and
 * tables. Each Lightning tab hosts this component with a different Page Key; the
 * as-of date and practice filters travel between tabs in the URL state.
 */
export default class BusinessHealthPage extends NavigationMixin(LightningElement) {
    @api pageKey = 'leadership';

    asOfParam = null;
    practiceParam = null;
    options;
    page;
    error;
    loading = true;
    wiredPageResult;
    tableState = {};

    @wire(CurrentPageReference)
    handlePageRef(ref) {
        const state = (ref && ref.state) || {};
        this.asOfParam = state.c__asOf || null;
        this.practiceParam = state.c__practice || null;
    }

    @wire(getFilterOptions)
    wiredOptions({ data, error }) {
        if (data) {
            this.options = data;
        } else if (error) {
            this.error = this.message(error);
        }
    }

    @wire(getPage, { pageKey: '$pageKey', asOfDate: '$asOfParam', practiceId: '$practiceParam' })
    wiredPage(result) {
        this.wiredPageResult = result;
        const { data, error } = result;
        if (data) {
            this.page = data;
            this.error = undefined;
            this.loading = false;
        } else if (error) {
            this.error = this.message(error);
            this.loading = false;
        }
    }

    // ---- header / nav / filters ------------------------------------------------------

    get pageTitle() {
        return this.page ? this.page.title : 'Business Health';
    }

    get pageSubtitle() {
        return this.page ? this.page.subtitle : '';
    }

    get audience() {
        return this.page ? this.page.audience : null;
    }

    get scopeLabel() {
        return this.page ? this.page.scopeLabel : '';
    }

    get goalSetLabel() {
        return this.page ? this.page.goalSetLabel : '';
    }

    get goalSetId() {
        return this.page ? this.page.goalSetId : null;
    }

    get navItems() {
        return ((this.options && this.options.pages) || []).map((p) => ({
            ...p,
            cls: p.key === this.pageKey ? 'nav-item nav-item-active' : 'nav-item',
            current: p.key === this.pageKey ? 'page' : null
        }));
    }

    get practiceOptions() {
        const list = [{ value: '', label: 'All practices', selected: !this.practiceParam }];
        ((this.options && this.options.practices) || []).forEach((p) =>
            list.push({ value: p.value, label: p.label, selected: p.value === this.practiceParam })
        );
        return list;
    }

    get asOfValue() {
        return this.asOfParam || (this.page && this.page.asOfDate) || '';
    }

    get showStaleBanner() {
        return this.page && this.page.asOfDefaulted && this.options && this.options.asOfIsStale;
    }

    get staleMessage() {
        return `The most recent approved timecards in this org end ${formatDate(this.page.asOfDate)}, so every trailing window is measured back from that date instead of today. Pick another as-of date above to change it.`;
    }

    get asOfLabel() {
        return this.page ? formatDate(this.page.asOfDate) : '';
    }

    get isCustomAsOf() {
        return !!this.asOfParam;
    }

    handleNav(event) {
        const tabName = event.currentTarget.dataset.tab;
        const state = {};
        if (this.asOfParam) {
            state.c__asOf = this.asOfParam;
        }
        if (this.practiceParam) {
            state.c__practice = this.practiceParam;
        }
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: tabName }, state });
    }

    handleAsOfChange(event) {
        this.setFilters(event.target.value || null, this.practiceParam);
    }

    handleResetAsOf() {
        this.setFilters(null, this.practiceParam);
    }

    handlePracticeChange(event) {
        this.setFilters(this.asOfParam, event.target.value || null);
    }

    setFilters(asOf, practice) {
        // Only show the spinner when the wire will actually re-run.
        if (asOf !== this.asOfParam || practice !== this.practiceParam) {
            this.loading = true;
            this.asOfParam = asOf;
            this.practiceParam = practice;
        }
    }

    handleRefresh() {
        this.loading = true;
        refreshApex(this.wiredPageResult).finally(() => {
            this.loading = false;
        });
    }

    // ---- KPI tiles ---------------------------------------------------------------------

    get kpis() {
        return ((this.page && this.page.kpis) || []).map((k) => {
            const status = k.unavailable ? 'neutral' : k.status || 'neutral';
            return {
                key: k.key,
                label: k.label,
                value: k.unavailable ? 'Not available' : formatValue(k.value, k.format, true),
                valueClass: k.unavailable ? 'kpi-value kpi-value-na' : 'kpi-value',
                tileClass: `kpi kpi-${status}`,
                statusClass: `status status-${status}`,
                statusText: k.unavailable ? 'Data gap' : STATUS_LABEL[status],
                statusIcon: STATUS_ICON[status],
                target: k.targetLabel ? `Target ${k.targetLabel.replace('>=', '≥').replace('<=', '≤')}` : '',
                note: k.note,
                spark: this.sparkline(k)
            };
        });
    }

    sparkline(k) {
        const vals = (k.trend || []).map((v) => (isBlank(v) ? null : Number(v)));
        const present = vals.filter((v) => v !== null);
        if (present.length < 2) {
            return null;
        }
        let min = Math.min(...present);
        let max = Math.max(...present);
        if (!isBlank(k.target)) {
            min = Math.min(min, Number(k.target));
            max = Math.max(max, Number(k.target));
        }
        const span = max - min || 1;
        const step = SPARK_W / (vals.length - 1);
        const y = (v) => SPARK_H - 3 - ((v - min) / span) * (SPARK_H - 6);
        let d = '';
        let pen = false;
        let last = null;
        vals.forEach((v, i) => {
            if (v === null) {
                pen = false;
                return;
            }
            d += `${pen ? 'L' : 'M'}${(i * step).toFixed(1)},${y(v).toFixed(1)} `;
            pen = true;
            last = { x: i * step, y: y(v) };
        });
        const labels = k.trendLabels || [];
        return {
            d,
            endX: last.x,
            endY: last.y,
            hasTarget: !isBlank(k.target),
            targetY: isBlank(k.target) ? 0 : y(Number(k.target)),
            viewBox: `-4 0 ${SPARK_W + 8} ${SPARK_H}`,
            caption: `${labels[0] || ''} to ${labels[labels.length - 1] || ''}`,
            title: vals.map((v, i) => `${labels[i] || ''}: ${formatValue(v, k.format)}`).join(', ')
        };
    }

    // ---- signals / gaps ------------------------------------------------------------------

    get signals() {
        const order = { bad: 0, warn: 1, info: 2, good: 3 };
        return ((this.page && this.page.signals) || [])
            .map((s, i) => ({
                key: `s${i}`,
                message: s.message,
                cls: `signal signal-${s.severity}`,
                icon: STATUS_ICON[s.severity] || 'i',
                rank: order[s.severity] === undefined ? 9 : order[s.severity]
            }))
            .sort((a, b) => a.rank - b.rank);
    }

    get hasSignals() {
        return this.signals.length > 0;
    }

    get dataGaps() {
        return ((this.page && this.page.dataGaps) || []).map((g, i) => ({ key: `g${i}`, text: g }));
    }

    get hasDataGaps() {
        return this.dataGaps.length > 0;
    }

    // ---- charts ------------------------------------------------------------------------

    get charts() {
        return ((this.page && this.page.charts) || []).map((c) => ({ ...c, cls: c.type === 'hbar' && (c.labels || []).length > 8 ? 'chart-cell chart-cell-tall' : 'chart-cell' }));
    }

    get hasCharts() {
        return this.charts.length > 0;
    }

    // ---- tables ------------------------------------------------------------------------

    get tables() {
        return ((this.page && this.page.tables) || []).map((t) => {
            const st = this.tableState[t.key] || {};
            let rows = [...(t.rows || [])];
            if (st.sortKey) {
                const dir = st.dir === 'asc' ? 1 : -1;
                rows.sort((a, b) => {
                    const av = a[st.sortKey];
                    const bv = b[st.sortKey];
                    if (isBlank(av)) {
                        return 1;
                    }
                    if (isBlank(bv)) {
                        return -1;
                    }
                    return (typeof av === 'number' && typeof bv === 'number' ? av - bv : String(av).localeCompare(String(bv))) * dir;
                });
            }
            const total = rows.length;
            if (!st.expanded) {
                rows = rows.slice(0, COLLAPSED_ROWS);
            }
            const columns = t.columns.map((c) => ({
                ...c,
                cls: NUMERIC_TYPES.has(c.type) ? 'num sortable' : 'sortable',
                indicator: st.sortKey === c.key ? (st.dir === 'asc' ? ' ▲' : ' ▼') : '',
                ariaSort: st.sortKey === c.key ? (st.dir === 'asc' ? 'ascending' : 'descending') : 'none'
            }));
            return {
                key: t.key,
                title: t.title,
                subtitle: t.subtitle,
                emptyMessage: t.emptyMessage,
                columns,
                hasRows: total > 0,
                rows: rows.map((r, i) => ({
                    key: `${t.key}-${i}`,
                    cells: t.columns.map((c) => this.cell(r, c, `${t.key}-${i}-${c.key}`))
                })),
                showToggle: total > COLLAPSED_ROWS,
                toggleLabel: st.expanded ? 'Show fewer' : `Show all ${total}`
            };
        });
    }

    cell(row, col, key) {
        const v = row[col.key];
        const base = { key, isLink: false, isStatus: false, cls: NUMERIC_TYPES.has(col.type) ? 'num' : '' };
        if (col.type === 'link') {
            const id = row[col.idKey];
            return { ...base, isLink: !!id, text: isBlank(v) ? '—' : v, recordId: id };
        }
        if (col.type === 'status') {
            const s = v || 'neutral';
            return { ...base, isStatus: true, statusClass: `status status-${s}`, icon: STATUS_ICON[s], text: STATUS_LABEL[s] };
        }
        if (col.type === 'date') {
            return { ...base, text: formatDate(v) };
        }
        if (NUMERIC_TYPES.has(col.type)) {
            return { ...base, text: formatValue(v, col.type === 'number' ? 'number' : col.type) };
        }
        return { ...base, text: isBlank(v) ? '—' : String(v) };
    }

    handleSort(event) {
        const table = event.currentTarget.dataset.table;
        const key = event.currentTarget.dataset.key;
        const st = this.tableState[table] || {};
        const dir = st.sortKey === key && st.dir === 'desc' ? 'asc' : 'desc';
        this.tableState = { ...this.tableState, [table]: { ...st, sortKey: key, dir } };
    }

    handleToggleRows(event) {
        const table = event.currentTarget.dataset.table;
        const st = this.tableState[table] || {};
        this.tableState = { ...this.tableState, [table]: { ...st, expanded: !st.expanded } };
    }

    handleOpenRecord(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    // ---- misc --------------------------------------------------------------------------

    get hasPage() {
        return !!this.page;
    }

    get advisorAsOf() {
        return this.asOfParam;
    }

    message(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
    }
}
