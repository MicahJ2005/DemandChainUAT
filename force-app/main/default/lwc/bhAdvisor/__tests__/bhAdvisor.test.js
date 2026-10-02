import { createElement } from 'lwc';
import BhAdvisor from 'c/bhAdvisor';
import getAdvice from '@salesforce/apex/BusinessHealthAdvisor.getAdvice';

jest.mock('@salesforce/apex/BusinessHealthAdvisor.getAdvice', () => ({ default: jest.fn() }), { virtual: true });

const ADVICE = {
    headline: 'Pipeline is thin for Q2.',
    assessment: 'Coverage is 0.7x against 3x.',
    recommendations: [
        { title: 'Build pipeline', action: 'Run account planning.', why: 'Coverage 0.7x', impact: '+$1M', owner: 'Sales leader', timeframe: 'This month', metric: 'Pipeline coverage' }
    ],
    watch: ['Weekly bookings'],
    dataFixes: ['Add FSC to Cloud(s) Included'],
    aiGenerated: true,
    fromCache: true,
    model: 'sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet',
    generatedAt: '2025-02-15T15:00:00.000Z'
};

function wait(ms = 80) {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    return new Promise((resolve) => setTimeout(resolve, ms));
}

describe('c-bh-advisor', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('loads advice once for the initial filters and renders it', async () => {
        getAdvice.mockResolvedValue(ADVICE);
        const el = createElement('c-bh-advisor', { is: BhAdvisor });
        el.pageKey = 'sales';
        el.practiceId = null;
        document.body.appendChild(el);
        await wait();
        expect(getAdvice).toHaveBeenCalledTimes(1);
        expect(getAdvice).toHaveBeenCalledWith({ pageKey: 'sales', asOfDate: null, practiceId: null, forceRefresh: false });
        expect(el.shadowRoot.querySelector('.headline').textContent).toBe('Pipeline is thin for Q2.');
        expect(el.shadowRoot.querySelectorAll('.rec')).toHaveLength(1);
        expect(el.shadowRoot.querySelector('.badge').textContent).toContain('Claude Sonnet 4.5');
        expect(el.shadowRoot.querySelector('.footer').textContent).toContain('Saved analysis');
    });

    it('forces a fresh analysis on Regenerate', async () => {
        getAdvice.mockResolvedValue(ADVICE);
        const el = createElement('c-bh-advisor', { is: BhAdvisor });
        el.pageKey = 'sales';
        document.body.appendChild(el);
        await wait();
        el.shadowRoot.querySelector('.btn-secondary').click();
        await wait(0);
        expect(getAdvice).toHaveBeenLastCalledWith(expect.objectContaining({ forceRefresh: true }));
    });

    it('labels rule-based fallback and shows its notice', async () => {
        getAdvice.mockResolvedValue({ ...ADVICE, aiGenerated: false, fromCache: false, notice: 'AI unavailable.' });
        const el = createElement('c-bh-advisor', { is: BhAdvisor });
        el.pageKey = 'finance';
        document.body.appendChild(el);
        await wait();
        expect(el.shadowRoot.querySelector('.badge').textContent).toContain('Rule-based');
        expect(el.shadowRoot.querySelector('.notice').textContent).toBe('AI unavailable.');
    });

    it('shows an error when the call fails', async () => {
        getAdvice.mockRejectedValue({ body: { message: 'No access' } });
        const el = createElement('c-bh-advisor', { is: BhAdvisor });
        el.pageKey = 'people';
        document.body.appendChild(el);
        await wait();
        expect(el.shadowRoot.querySelector('.error').textContent).toContain('No access');
    });
});
