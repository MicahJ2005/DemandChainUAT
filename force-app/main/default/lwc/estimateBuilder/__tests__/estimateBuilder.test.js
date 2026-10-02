import { createElement } from 'lwc';
import EstimateBuilder from 'c/estimateBuilder';

jest.mock('@salesforce/apex/EstimateController.getEstimateVersions', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/EstimateController.getDefaultRateCard', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/EstimateController.getEstimate', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EstimateController.saveEstimate', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EstimateController.createNewVersion', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EstimateController.activateVersion', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EstimateController.deleteEstimate', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EstimateExportController.generatePdf', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EstimateExportController.generateWord', () => ({ default: jest.fn() }), { virtual: true });

describe('c-estimate-builder', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the toolbar and tabs without throwing', () => {
        const element = createElement('c-estimate-builder', { is: EstimateBuilder });
        element.recordId = '006000000000001AAA';
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('.toolbar')).not.toBeNull();
        expect(element.shadowRoot.querySelectorAll('.tabs .tab')).toHaveLength(6);
    });

    it('defaults to the Project Info tab', () => {
        const element = createElement('c-estimate-builder', { is: EstimateBuilder });
        element.recordId = '006000000000001AAA';
        document.body.appendChild(element);

        const activeTab = element.shadowRoot.querySelector('.tab.active');
        expect(activeTab.textContent).toBe('Project Info');
    });
});
