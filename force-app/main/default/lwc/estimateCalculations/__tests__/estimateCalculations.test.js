import {
    nz,
    lineTotalHours,
    lineCost,
    linePrice,
    marginPercent,
    recalcLine,
    sumField,
    phaseWeeks,
    totalWeeksForHeader,
    phaseSegments,
    weeklyJsonToPhaseHours
} from 'c/estimateCalculations';

describe('nz', () => {
    it('treats null, undefined, and empty string as zero', () => {
        expect(nz(null)).toBe(0);
        expect(nz(undefined)).toBe(0);
        expect(nz('')).toBe(0);
    });
    it('passes through numeric values', () => {
        expect(nz(5)).toBe(5);
        expect(nz('12.5')).toBe(12.5);
    });
});

describe('lineTotalHours', () => {
    it('sums all phase hours for a Team Resource line', () => {
        const line = {
            Line_Type__c: 'Team Resource',
            Planning_Hours__c: 10,
            Discovery_Hours__c: 5,
            PB_Hours__c: 40,
            Deploy_Hours__c: 8,
            Wrapup_Hours__c: 2
        };
        expect(lineTotalHours(line)).toBe(65);
    });

    it('uses Hours_Per_Week__c for an MS Tier line', () => {
        expect(lineTotalHours({ Line_Type__c: 'MS Tier', Hours_Per_Week__c: 20 })).toBe(20);
    });

    it('falls back to Total_Hours__c for other line types', () => {
        expect(lineTotalHours({ Line_Type__c: 'T&M Line', Total_Hours__c: 15 })).toBe(15);
    });
});

describe('lineCost and linePrice', () => {
    it('computes cost and price from hours for a Team Resource line', () => {
        const line = {
            Line_Type__c: 'Team Resource',
            Planning_Hours__c: 10,
            Cost_Per_Hour__c: 75,
            Price_Per_Hour__c: 145
        };
        expect(lineCost(line)).toBe(750);
        expect(linePrice(line)).toBe(1450);
    });

    it('uses the fixed price (not hours * rate) for a Fixed Deliverable line', () => {
        const line = {
            Line_Type__c: 'Fixed Deliverable',
            Total_Hours__c: 20,
            Cost_Per_Hour__c: 75,
            Price_Per_Hour__c: 145,
            Fixed_Price__c: 5000
        };
        expect(lineCost(line)).toBe(1500);
        expect(linePrice(line)).toBe(5000);
    });
});

describe('marginPercent', () => {
    it('returns 0 when price is 0 to avoid divide-by-zero', () => {
        expect(marginPercent(0, 100)).toBe(0);
    });
    it('computes margin as a percentage', () => {
        expect(marginPercent(200, 100)).toBe(50);
    });
});

describe('recalcLine', () => {
    it('recomputes Total_Hours__c, Line_Cost__c, Line_Price__c, and Margin__c', () => {
        const result = recalcLine({
            Line_Type__c: 'Team Resource',
            Planning_Hours__c: 10,
            Cost_Per_Hour__c: 75,
            Price_Per_Hour__c: 145
        });
        expect(result.Total_Hours__c).toBe(10);
        expect(result.Line_Cost__c).toBe(750);
        expect(result.Line_Price__c).toBe(1450);
        expect(result.Margin__c).toBeCloseTo(48.28, 1);
    });
});

describe('sumField', () => {
    const lines = [
        { Line_Price__c: 100, Include_In_Rollup__c: true },
        { Line_Price__c: 50, Include_In_Rollup__c: false },
        { Line_Price__c: 25, Include_In_Rollup__c: true }
    ];

    it('sums every line when includedOnly is false', () => {
        expect(sumField(lines, 'Line_Price__c', false)).toBe(175);
    });

    it('skips lines with Include_In_Rollup__c = false when includedOnly is true', () => {
        expect(sumField(lines, 'Line_Price__c', true)).toBe(125);
    });
});

describe('phaseWeeks / totalWeeksForHeader', () => {
    const header = {
        Planning_Weeks__c: 1,
        Discovery_Weeks__c: 2,
        PB_Sprints__c: 6,
        Sprint_Length_Weeks__c: 2,
        Deploy_Weeks__c: 1,
        Wrapup_Weeks__c: 1
    };

    it('multiplies sprints by sprint length for the plan & build phase', () => {
        expect(phaseWeeks(header).pb).toBe(12);
    });

    it('sums every phase for the total timeline length', () => {
        expect(totalWeeksForHeader(header)).toBe(17);
    });
});

describe('phaseSegments', () => {
    it('produces segments whose widths sum to 100%', () => {
        const segments = phaseSegments({
            Planning_Weeks__c: 1,
            Discovery_Weeks__c: 1,
            PB_Sprints__c: 1,
            Sprint_Length_Weeks__c: 1,
            Deploy_Weeks__c: 1,
            Wrapup_Weeks__c: 1
        });
        const totalWidth = segments.reduce((sum, s) => sum + s.widthPercent, 0);
        expect(totalWidth).toBeCloseTo(100, 5);
        expect(segments).toHaveLength(5);
    });
});

describe('weeklyJsonToPhaseHours', () => {
    it('maps week-indexed hours into the phase they fall within', () => {
        const header = {
            Planning_Weeks__c: 1,
            Discovery_Weeks__c: 1,
            PB_Sprints__c: 2,
            Sprint_Length_Weeks__c: 1,
            Deploy_Weeks__c: 1,
            Wrapup_Weeks__c: 1
        };
        // weeks: 1=planning, 2=discovery, 3-4=pb, 5=deploy, 6=wrapup
        const json = JSON.stringify({ 1: 10, 2: 5, 3: 20, 4: 20, 5: 8, 6: 4 });
        const result = weeklyJsonToPhaseHours(json, header);
        expect(result.Planning_Hours__c).toBe(10);
        expect(result.Discovery_Hours__c).toBe(5);
        expect(result.PB_Hours__c).toBe(40);
        expect(result.Deploy_Hours__c).toBe(8);
        expect(result.Wrapup_Hours__c).toBe(4);
    });

    it('returns all zeros for invalid JSON instead of throwing', () => {
        const result = weeklyJsonToPhaseHours('not json', {});
        expect(result.Planning_Hours__c).toBe(0);
    });
});
