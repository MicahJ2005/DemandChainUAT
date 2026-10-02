import { LightningElement, api } from 'lwc';
import { phaseSegments } from 'c/estimateCalculations';

const CHART_WIDTH = 1000;

/**
 * Inline SVG phase timeline, ported from the original standalone tool's
 * gantt-style infographic. Segment widths are proportional to each phase's
 * length in weeks.
 */
export default class EstimateTimelineChart extends LightningElement {
    @api header = {};

    get segments() {
        return phaseSegments(this.header).map((seg) => {
            const widthPx = (seg.widthPercent / 100) * CHART_WIDTH;
            const xPx = (seg.xPercent / 100) * CHART_WIDTH;
            return {
                ...seg,
                xPx,
                widthPx,
                labelX: xPx + widthPx / 2,
                weeksLabel: `${seg.weeks}w`,
                swatchStyle: `background-color:${seg.color}`
            };
        });
    }
}
