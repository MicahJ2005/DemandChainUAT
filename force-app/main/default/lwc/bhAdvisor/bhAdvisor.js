import { LightningElement, api } from 'lwc';
import getAdvice from '@salesforce/apex/BusinessHealthAdvisor.getAdvice';
import { modelLabel } from 'c/bhFormat';

const DATETIME = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });

/**
 * AI Advisor panel for a Business Health page. Asks BusinessHealthAdvisor (Einstein
 * Models API) for advice whenever the page, as-of date or practice changes; the
 * server rebuilds the page itself, so only the filters are sent. Stored advice for the
 * same view is reused server-side, and "Regenerate" forces a fresh analysis.
 */
export default class BhAdvisor extends LightningElement {
    _pageKey;
    _asOfDate;
    _practiceId;

    advice;
    error;
    loading = false;
    requestSeq = 0;
    connected = false;

    @api
    get pageKey() {
        return this._pageKey;
    }
    set pageKey(v) {
        this._pageKey = v;
        this.scheduleLoad();
    }

    @api
    get asOfDate() {
        return this._asOfDate;
    }
    set asOfDate(v) {
        this._asOfDate = v;
        this.scheduleLoad();
    }

    @api
    get practiceId() {
        return this._practiceId;
    }
    set practiceId(v) {
        this._practiceId = v;
        this.scheduleLoad();
    }

    connectedCallback() {
        this.connected = true;
        this.scheduleLoad();
    }

    scheduleLoad() {
        if (!this.connected || !this._pageKey) {
            return;
        }
        // Batch the three setters that fire together on first render into one call.
        clearTimeout(this.timer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.timer = setTimeout(() => this.load(false), 50);
    }

    handleRegenerate() {
        this.load(true);
    }

    async load(forceRefresh) {
        const seq = ++this.requestSeq;
        this.loading = true;
        this.error = undefined;
        try {
            const result = await getAdvice({
                pageKey: this._pageKey,
                asOfDate: this._asOfDate || null,
                practiceId: this._practiceId || null,
                forceRefresh
            });
            // Ignore responses for a filter combination the user has already moved past.
            if (seq === this.requestSeq) {
                this.advice = result;
            }
        } catch (e) {
            if (seq === this.requestSeq) {
                this.error = (e && e.body && e.body.message) || (e && e.message) || 'Unknown error';
            }
        } finally {
            if (seq === this.requestSeq) {
                this.loading = false;
            }
        }
    }

    get hasAdvice() {
        return !!this.advice && !this.loading;
    }

    get recommendations() {
        return ((this.advice && this.advice.recommendations) || []).map((r, i) => ({
            ...r,
            key: `rec${i}`,
            number: i + 1,
            hasMeta: !!(r.owner || r.timeframe || r.metric)
        }));
    }

    get watch() {
        return ((this.advice && this.advice.watch) || []).map((w, i) => ({ key: `w${i}`, text: w }));
    }

    get dataFixes() {
        return ((this.advice && this.advice.dataFixes) || []).map((w, i) => ({ key: `d${i}`, text: w }));
    }

    get hasWatch() {
        return this.watch.length > 0;
    }

    get hasDataFixes() {
        return this.dataFixes.length > 0;
    }

    get badgeLabel() {
        if (!this.advice) {
            return 'AI Advisor';
        }
        return this.advice.aiGenerated ? `AI Advisor · ${modelLabel(this.advice.model)}` : 'Rule-based guidance';
    }

    get footer() {
        if (!this.advice) {
            return '';
        }
        const when = this.advice.generatedAt ? DATETIME.format(new Date(this.advice.generatedAt)) : '';
        if (!this.advice.aiGenerated) {
            return `Generated ${when} from this page's off-target KPIs.`;
        }
        const cached = this.advice.fromCache ? ' Saved analysis; select Regenerate for a fresh one.' : '';
        return `Generated ${when} by ${modelLabel(this.advice.model)} via Einstein from the numbers on this page. AI can be wrong, so verify before acting.${cached}`;
    }

    get panelClass() {
        return this.advice && !this.advice.aiGenerated ? 'advisor advisor-rules' : 'advisor';
    }

    get regenerateLabel() {
        return this.loading ? 'Analyzing…' : 'Regenerate';
    }
}
