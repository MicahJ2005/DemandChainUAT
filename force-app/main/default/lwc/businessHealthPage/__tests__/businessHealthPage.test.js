import { createElement } from 'lwc';
import BusinessHealthPage from 'c/businessHealthPage';
import getPage from '@salesforce/apex/BusinessHealthController.getPage';
import getFilterOptions from '@salesforce/apex/BusinessHealthController.getFilterOptions';
import getAdvice from '@salesforce/apex/BusinessHealthAdvisor.getAdvice';
import { CurrentPageReference } from 'lightning/navigation';

jest.mock(
    '@salesforce/apex/BusinessHealthController.getPage',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/BusinessHealthController.getFilterOptions',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock('@salesforce/apex/BusinessHealthAdvisor.getAdvice', () => ({ default: jest.fn() }), { virtual: true });

const OPTIONS = {
    practices: [{ value: 'a1B000000000001', label: 'Managed Services' }],
    pages: [
        { key: 'leadership', label: 'Leadership', tabName: 'Business_Health_Leadership' },
        { key: 'sales', label: 'Sales & Pipeline', tabName: 'Business_Health_Sales' }
    ],
    defaultAsOfDate: '2025-02-15',
    asOfIsStale: true,
    aiEnabled: true
};

const PAGE = {
    key: 'leadership',
    title: 'Leadership Scorecard',
    subtitle: 'Firm-level signals.',
    audience: 'Leadership',
    asOfDate: '2025-02-15',
    asOfDefaulted: true,
    scopeLabel: 'All practices',
    kpis: [
        {
            key: 'bookToBill',
            label: 'Book-to-bill (T3M)',
            value: 0.8,
            format: 'ratio',
            target: 1.1,
            targetLabel: '>= 1.10x',
            direction: 'higher',
            status: 'bad',
            note: 'Bookings / delivered.',
            trend: [1.2, 1.0, 0.9, 0.8],
            trendLabels: ['Nov 24', 'Dec 24', 'Jan 25', 'Feb 25'],
            unavailable: false
        },
        { key: 'dso', label: 'DSO', value: null, format: 'days', status: 'neutral', note: 'Needs payment data.', unavailable: true }
    ],
    charts: [
        {
            key: 'revenueMix',
            title: 'Revenue',
            type: 'bar',
            format: 'currency',
            labels: ['Jan', 'Feb'],
            series: [
                { name: 'Bookings', values: [100, 200] },
                { name: 'Delivered', values: [150, 120] }
            ]
        }
    ],
    tables: [
        {
            key: 'projects',
            title: 'Projects',
            columns: [
                { key: 'name', label: 'Project', type: 'link', idKey: 'id' },
                { key: 'revenue', label: 'Revenue', type: 'currency' },
                { key: 'status', label: 'Status', type: 'status' }
            ],
            rows: Array.from({ length: 12 }, (_, i) => ({ id: `a1E00000000000${i}`, name: `Project ${i}`, revenue: i * 1000, status: i % 2 ? 'good' : 'bad' }))
        }
    ],
    signals: [
        { severity: 'warn', message: 'Watch this.' },
        { severity: 'bad', message: 'Fix this first.' }
    ],
    dataGaps: ['DSO needs payment dates.']
};

function flush() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-business-health-page', () => {
    beforeEach(() => {
        getAdvice.mockResolvedValue({ headline: 'Advice', recommendations: [], watch: [], dataFixes: [], aiGenerated: true });
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function render() {
        const element = createElement('c-business-health-page', { is: BusinessHealthPage });
        element.pageKey = 'leadership';
        document.body.appendChild(element);
        CurrentPageReference.emit({ state: {} });
        getFilterOptions.emit(OPTIONS);
        getPage.emit(PAGE);
        await flush();
        return element;
    }

    it('renders KPI tiles with status chips, including an unavailable metric', async () => {
        const element = await render();
        const tiles = element.shadowRoot.querySelectorAll('.kpi');
        expect(tiles).toHaveLength(2);
        expect(tiles[0].classList).toContain('kpi-bad');
        expect(tiles[0].querySelector('.kpi-value').textContent).toBe('0.80x');
        expect(tiles[0].querySelector('.status').textContent).toContain('Off target');
        expect(tiles[0].querySelector('.spark')).not.toBeNull();
        expect(tiles[1].querySelector('.kpi-value').textContent).toBe('Not available');
    });

    it('shows the stale-data banner, navigation and practice filter', async () => {
        const element = await render();
        expect(element.shadowRoot.querySelector('.banner').textContent).toContain('Feb 15, 2025');
        const nav = element.shadowRoot.querySelectorAll('.nav-item');
        expect(nav).toHaveLength(2);
        expect(nav[0].classList).toContain('nav-item-active');
        expect(element.shadowRoot.querySelectorAll('select option')).toHaveLength(2);
    });

    it('orders signals by severity', async () => {
        const element = await render();
        const signals = element.shadowRoot.querySelectorAll('.signal');
        expect(signals[0].textContent).toContain('Fix this first.');
    });

    it('collapses long tables and expands on request', async () => {
        const element = await render();
        const card = [...element.shadowRoot.querySelectorAll('.card')].find((c) => c.querySelector('h2').textContent === 'Projects');
        expect(card.querySelectorAll('tbody tr')).toHaveLength(10);
        card.querySelector('.toggle').click();
        await flush();
        expect(card.querySelectorAll('tbody tr')).toHaveLength(12);
    });

    it('sorts a table column when its header is clicked', async () => {
        const element = await render();
        const card = [...element.shadowRoot.querySelectorAll('.card')].find((c) => c.querySelector('h2').textContent === 'Projects');
        card.querySelectorAll('.th-btn')[1].click();
        await flush();
        expect(card.querySelector('tbody tr td').textContent).toBe('Project 11');
    });

    it('passes the page key to the AI Advisor', async () => {
        const element = await render();
        const advisor = element.shadowRoot.querySelector('c-bh-advisor');
        expect(advisor.pageKey).toBe('leadership');
    });

    it('shows an error banner when the page fails to load', async () => {
        const element = createElement('c-business-health-page', { is: BusinessHealthPage });
        document.body.appendChild(element);
        getPage.error({ message: 'Boom' });
        await flush();
        expect(element.shadowRoot.querySelector('.banner-error').textContent).toContain('Boom');
    });
});
