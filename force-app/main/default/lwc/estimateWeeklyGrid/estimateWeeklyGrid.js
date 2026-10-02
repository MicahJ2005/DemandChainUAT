import { LightningElement, api } from 'lwc';
import { totalWeeksForHeader, nz, parseWeeklyHours } from 'c/estimateCalculations';

/**
 * Click-and-drag "fill handle" weekly hours grid for Team Resource lines.
 * Mirrors the original standalone tool's paint-across-weeks interaction:
 * mousedown on a cell captures its value, dragging across other cells in the
 * same row paints that value, mouseup (or a direct change) commits the row
 * and notifies the parent with the row's updated Weekly_Hours_JSON__c.
 */
export default class EstimateWeeklyGrid extends LightningElement {
    @api header = {};
    @api lines = [];

    painting = false;
    paintRow = null;
    paintValue = '';

    get weekColumns() {
        const total = totalWeeksForHeader(this.header);
        return Array.from({ length: total }, (_, i) => ({ index: i + 1, label: `W${i + 1}` }));
    }

    get rows() {
        const cols = this.weekColumns;
        return (this.lines || []).map((line) => {
            const map = parseWeeklyHours(line.Weekly_Hours_JSON__c);
            let total = 0;
            const cells = cols.map((c) => {
                const value = nz(map[c.index]);
                total += value;
                return {
                    key: `${line.key}_${c.index}`,
                    week: c.index,
                    value: value || null
                };
            });
            return { key: line.key, label: line.Name || 'Resource', cells, total };
        });
    }

    get hasRows() {
        return (this.lines || []).length > 0;
    }

    handleMouseDown(event) {
        this.painting = true;
        this.paintRow = event.target.dataset.row;
        this.paintValue = event.target.value;
    }

    handleMouseOver(event) {
        if (!this.painting) {
            return;
        }
        if (event.target.dataset.row !== this.paintRow) {
            return;
        }
        event.target.value = this.paintValue;
    }

    handleMouseUp() {
        if (!this.painting) {
            return;
        }
        this.painting = false;
        this.commitRow(this.paintRow);
    }

    handleDirectChange(event) {
        this.commitRow(event.target.dataset.row);
    }

    commitRow(rowKey) {
        if (!rowKey) {
            return;
        }
        const inputs = this.template.querySelectorAll(`input[data-row="${rowKey}"]`);
        const map = {};
        inputs.forEach((input) => {
            const val = Number(input.value);
            if (val) {
                map[input.dataset.week] = val;
            }
        });
        this.dispatchEvent(
            new CustomEvent('weeklyhourschange', {
                detail: { key: rowKey, weeklyHoursJson: JSON.stringify(map) }
            })
        );
    }
}
