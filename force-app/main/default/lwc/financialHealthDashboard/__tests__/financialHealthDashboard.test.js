import { createElement } from 'lwc';
import FinancialHealthDashboard from 'c/financialHealthDashboard';
import getCurrentProjects from '@salesforce/apex/FinancialHealthController.getCurrentProjects';
import getNearCloseOpportunities from '@salesforce/apex/FinancialHealthController.getNearCloseOpportunities';
import getResourceCapacity from '@salesforce/apex/FinancialHealthController.getResourceCapacity';

jest.mock('@salesforce/apex/FinancialHealthController.getCurrentProjects', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/FinancialHealthController.getNearCloseOpportunities', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/FinancialHealthController.getResourceCapacity', () => ({ default: jest.fn() }), {
    virtual: true
});

function flushPromises() {
    return Promise.resolve();
}

describe('c-financial-health-dashboard', () => {
    beforeEach(() => {
        getCurrentProjects.mockResolvedValue([]);
        getNearCloseOpportunities.mockResolvedValue([]);
        getResourceCapacity.mockResolvedValue([]);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders the header, KPI strip, and controls without throwing', () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('.header h1').textContent).toBe('Financial Health');
        expect(element.shadowRoot.querySelectorAll('.kpi')).toHaveLength(6);
        expect(element.shadowRoot.querySelectorAll('.kpi-hero')).toHaveLength(2);
    });

    it('defaults the months-out and min-probability controls', () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);

        // LWC's synthetic shadow DOM suffixes id attributes per instance
        // (months-out -> months-out-0), so select by structure instead.
        const inputs = element.shadowRoot.querySelectorAll('.controls input[type="number"]');
        expect(inputs).toHaveLength(2);
        expect(inputs[0].value).toBe('2');
        expect(inputs[1].value).toBe('80');
    });

    it('renders all 7 stage checkboxes, defaulting to the 3 active stages checked', () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);

        const checkboxes = element.shadowRoot.querySelectorAll('.stage-checkbox input[type="checkbox"]');
        expect(checkboxes).toHaveLength(7);
        const checkedValues = Array.from(checkboxes)
            .filter((cb) => cb.checked)
            .map((cb) => cb.dataset.value);
        expect(checkedValues.sort()).toEqual(['In Progress', 'Planning', 'Wrapping_Up'].sort());
    });

    it('adds a stage to the selection when its checkbox is checked', async () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);
        await Promise.resolve();

        let closedCheckbox = Array.from(
            element.shadowRoot.querySelectorAll('.stage-checkbox input[type="checkbox"]')
        ).find((cb) => cb.dataset.value === 'Closed');
        expect(closedCheckbox.checked).toBe(false);

        closedCheckbox.checked = true;
        closedCheckbox.dispatchEvent(new CustomEvent('change'));
        await Promise.resolve();

        closedCheckbox = Array.from(
            element.shadowRoot.querySelectorAll('.stage-checkbox input[type="checkbox"]')
        ).find((cb) => cb.dataset.value === 'Closed');
        expect(closedCheckbox.checked).toBe(true);
    });

    it('defaults to the Overview tab, with the Resource Capacity tab hidden until clicked', async () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('.card h2').textContent).toBe('Current Projects');
        expect(element.shadowRoot.querySelector('.rate-input')).toBeNull();

        const tabButtons = element.shadowRoot.querySelectorAll('.tab-btn');
        const resourceTabButton = Array.from(tabButtons).find((btn) => btn.textContent === 'Resource Capacity');
        resourceTabButton.click();
        await Promise.resolve();

        const cardHeadings = Array.from(element.shadowRoot.querySelectorAll('.card h2')).map((h) => h.textContent);
        expect(cardHeadings).toContain('Resource Capacity');
        expect(element.shadowRoot.querySelector('.rate-input')).not.toBeNull();
    });

    it('defaults the average billing rate input and lets it be changed', async () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);
        await flushPromises();

        const resourceTabButton = Array.from(element.shadowRoot.querySelectorAll('.tab-btn')).find(
            (btn) => btn.textContent === 'Resource Capacity'
        );
        resourceTabButton.click();
        await Promise.resolve();

        let rateInput = element.shadowRoot.querySelector('.rate-input');
        expect(rateInput.value).toBe('150');

        rateInput.value = '200';
        rateInput.dispatchEvent(new CustomEvent('change'));
        await Promise.resolve();

        rateInput = element.shadowRoot.querySelector('.rate-input');
        expect(rateInput.value).toBe('200');
    });

    function toIsoDate(d) {
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
    }

    it('defaults the Resource Capacity period to the current month, and switching to Week resets the range to a 7-day window', async () => {
        const now = new Date();
        const expectedMonthStart = toIsoDate(new Date(now.getFullYear(), now.getMonth(), 1));
        const expectedMonthEnd = toIsoDate(new Date(now.getFullYear(), now.getMonth() + 1, 0));
        const expectedWeekStart = toIsoDate(now);
        const weekEnd = new Date(now);
        weekEnd.setDate(weekEnd.getDate() + 6);
        const expectedWeekEnd = toIsoDate(weekEnd);

        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);
        await flushPromises();

        const resourceTabButton = Array.from(element.shadowRoot.querySelectorAll('.tab-btn')).find(
            (btn) => btn.textContent === 'Resource Capacity'
        );
        resourceTabButton.click();
        await Promise.resolve();

        const periodSelect = element.shadowRoot.querySelector('.controls select');
        const dateInputs = element.shadowRoot.querySelectorAll('.controls input[type="date"]');
        expect(periodSelect.value).toBe('Month');
        expect(dateInputs[0].value).toBe(expectedMonthStart);
        expect(dateInputs[1].value).toBe(expectedMonthEnd);

        periodSelect.value = 'Week';
        periodSelect.dispatchEvent(new CustomEvent('change'));
        await Promise.resolve();

        const updatedDateInputs = element.shadowRoot.querySelectorAll('.controls input[type="date"]');
        expect(updatedDateInputs[0].value).toBe(expectedWeekStart);
        expect(updatedDateInputs[1].value).toBe(expectedWeekEnd);
    });

    it('lets the resource capacity date range be set explicitly, independent of the period toggle', async () => {
        const element = createElement('c-financial-health-dashboard', { is: FinancialHealthDashboard });
        document.body.appendChild(element);
        await flushPromises();

        const resourceTabButton = Array.from(element.shadowRoot.querySelectorAll('.tab-btn')).find(
            (btn) => btn.textContent === 'Resource Capacity'
        );
        resourceTabButton.click();
        await Promise.resolve();

        const dateInputs = element.shadowRoot.querySelectorAll('.controls input[type="date"]');
        const startInput = dateInputs[0];
        const endInput = dateInputs[1];

        startInput.value = '2026-01-01';
        startInput.dispatchEvent(new CustomEvent('change'));
        endInput.value = '2026-03-31';
        endInput.dispatchEvent(new CustomEvent('change'));
        await Promise.resolve();

        const updatedDateInputs = element.shadowRoot.querySelectorAll('.controls input[type="date"]');
        expect(updatedDateInputs[0].value).toBe('2026-01-01');
        expect(updatedDateInputs[1].value).toBe('2026-03-31');
        expect(element.shadowRoot.querySelector('.window-note').textContent).toContain('2026-01-01');
        expect(element.shadowRoot.querySelector('.window-note').textContent).toContain('2026-03-31');
    });
});
