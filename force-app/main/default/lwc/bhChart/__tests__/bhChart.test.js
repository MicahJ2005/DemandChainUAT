import { createElement } from 'lwc';
import BhChart from 'c/bhChart';

function flush() {
    return Promise.resolve();
}

function mount(chart) {
    const element = createElement('c-bh-chart', { is: BhChart });
    element.chart = chart;
    document.body.appendChild(element);
    return element;
}

describe('c-bh-chart', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('draws grouped bars with a legend and a target line', () => {
        const el = mount({
            title: 'Revenue',
            type: 'bar',
            format: 'currency',
            labels: ['Jan', 'Feb', 'Mar'],
            series: [
                { name: 'Bookings', values: [100, 200, 300] },
                { name: 'Delivered', values: [150, 120, null] }
            ],
            targetLine: 180,
            targetLabel: 'Target'
        });
        expect(el.shadowRoot.querySelectorAll('path')).toHaveLength(5);
        expect(el.shadowRoot.querySelectorAll('.legend-item')).toHaveLength(3);
        expect(el.shadowRoot.querySelector('.target-line')).not.toBeNull();
    });

    it('breaks lines at nulls and shows a tooltip on hover', async () => {
        const el = mount({
            title: 'Utilization',
            type: 'line',
            format: 'percent',
            labels: ['W1', 'W2', 'W3'],
            series: [
                { name: 'Actual', values: [60, 70, null] },
                { name: 'Scheduled', values: [null, null, 50] }
            ]
        });
        const lines = el.shadowRoot.querySelectorAll('.series-line');
        expect(lines).toHaveLength(2);
        expect(lines[0].getAttribute('d').match(/M/g)).toHaveLength(1);
        el.shadowRoot.querySelectorAll('.hit')[1].dispatchEvent(new CustomEvent('mouseenter'));
        await flush();
        const tip = el.shadowRoot.querySelector('.tooltip');
        expect(tip.textContent).toContain('W2');
        expect(tip.textContent).toContain('70%');
    });

    it('draws horizontal bars with direct value labels for one series', () => {
        const el = mount({
            title: 'Margin by practice',
            type: 'hbar',
            format: 'percent',
            labels: ['A', 'B'],
            series: [{ name: 'Margin', values: [40, -5] }]
        });
        expect(el.shadowRoot.querySelectorAll('.value-label')).toHaveLength(2);
        expect(el.shadowRoot.querySelectorAll('.row-label')).toHaveLength(2);
    });

    it('offers a table view and an empty state', async () => {
        const el = mount({ title: 'Empty', type: 'bar', format: 'number', labels: ['A'], series: [{ name: 'S', values: [0] }] });
        expect(el.shadowRoot.querySelector('.empty')).not.toBeNull();
        el.shadowRoot.querySelector('.link-btn').click();
        await flush();
        expect(el.shadowRoot.querySelectorAll('.data-table tbody tr')).toHaveLength(1);
    });
});
