/**
 * @group BusinessHealth
 *
 * @description Data transfer objects shared by every Business Health page. Each page
 * builder returns one Page made of generic parts (KPI tiles, charts, tables, signals)
 * so a single LWC (businessHealthPage) can render any page, and the AI Advisor can
 * serialize any page into a prompt without page-specific code.
 *
 * Percent values are carried as 0-100 numbers (not 0-1) throughout, so the client
 * formats them without re-scaling.
 */
public with sharing class BusinessHealthModel {
    public static final String STATUS_GOOD = 'good';
    public static final String STATUS_WARN = 'warn';
    public static final String STATUS_BAD = 'bad';
    public static final String STATUS_NEUTRAL = 'neutral';
    public static final String STATUS_INFO = 'info';

    public class HealthPage {
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String subtitle;
        @AuraEnabled
        public String audience;
        @AuraEnabled
        public Date asOfDate;
        @AuraEnabled
        public Boolean asOfDefaulted;
        @AuraEnabled
        public String scopeLabel;
        /** The goal set(s) this page's targets come from. */
        @AuraEnabled
        public String goalSetLabel;
        @AuraEnabled
        public Id goalSetId;
        @AuraEnabled
        public List<Kpi> kpis = new List<Kpi>();
        @AuraEnabled
        public List<Chart> charts = new List<Chart>();
        @AuraEnabled
        public List<Table> tables = new List<Table>();
        @AuraEnabled
        public List<Signal> signals = new List<Signal>();
        @AuraEnabled
        public List<String> dataGaps = new List<String>();

        public HealthPage(String key, String title, String subtitle, String audience) {
            this.key = key;
            this.title = title;
            this.subtitle = subtitle;
            this.audience = audience;
        }

        public Kpi addKpi(Kpi k) {
            kpis.add(k);
            return k;
        }

        public void signal(String severity, String message) {
            signals.add(new Signal(severity, message));
        }

        /**
         * @description Adds a warn/bad signal for every KPI that missed its target, so
         * the page's signal list and the AI prompt always agree with the tile colors.
         */
        public void signalMissedKpis() {
            for (Kpi k : kpis) {
                if (k.status == STATUS_BAD || k.status == STATUS_WARN) {
                    signals.add(new Signal(k.status, k.label + ' is ' + k.displayValue() + ' against a target of ' + k.targetLabel + '.'));
                }
            }
        }
    }

    public class Kpi {
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Decimal value;
        /** currency | percent | number | ratio | months | days | hours | score */
        @AuraEnabled
        public String format;
        @AuraEnabled
        public Decimal target;
        @AuraEnabled
        public String targetLabel;
        /** higher | lower - which direction is better */
        @AuraEnabled
        public String direction;
        @AuraEnabled
        public String status = STATUS_NEUTRAL;
        @AuraEnabled
        public String note;
        @AuraEnabled
        public List<Decimal> trend;
        @AuraEnabled
        public List<String> trendLabels;
        @AuraEnabled
        public Boolean unavailable = false;

        public Kpi(String key, String label, Decimal value, String format) {
            this.key = key;
            this.label = label;
            this.value = value;
            this.format = format;
        }

        /**
         * @description Sets the target and derives status. Within `warnBand` (a
         * fraction of target, e.g. 0.1 = 10%) of the target on the wrong side is warn;
         * beyond it is bad.
         */
        public Kpi target(Decimal target, String direction, Decimal warnBand) {
            this.target = target;
            this.direction = direction;
            this.targetLabel = (direction == 'lower' ? '<= ' : '>= ') + formatValue(target, format);
            this.status = evaluate(value, target, direction, warnBand);
            return this;
        }

        public Kpi note(String note) {
            this.note = note;
            return this;
        }

        public Kpi trend(List<String> labels, List<Decimal> values) {
            this.trendLabels = labels;
            this.trend = values;
            return this;
        }

        public Kpi markUnavailable(String reason) {
            this.unavailable = true;
            this.status = STATUS_NEUTRAL;
            this.note = reason;
            return this;
        }

        public String displayValue() {
            return unavailable ? 'not available' : formatValue(value, format);
        }
    }

    public class Chart {
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String subtitle;
        /** bar | line | hbar */
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String format;
        @AuraEnabled
        public List<String> labels = new List<String>();
        @AuraEnabled
        public List<Series> series = new List<Series>();
        @AuraEnabled
        public Decimal targetLine;
        @AuraEnabled
        public String targetLabel;

        public Chart(String key, String title, String type, String format) {
            this.key = key;
            this.title = title;
            this.type = type;
            this.format = format;
        }

        public Chart addSeries(String name, List<Decimal> values) {
            series.add(new Series(name, values));
            return this;
        }

        public Chart labels(List<String> labels) {
            this.labels = labels;
            return this;
        }

        public Chart target(Decimal value, String label) {
            this.targetLine = value;
            this.targetLabel = label;
            return this;
        }
    }

    public class Series {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public List<Decimal> values;

        public Series(String name, List<Decimal> values) {
            this.name = name;
            this.values = values;
        }
    }

    public class Table {
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String subtitle;
        @AuraEnabled
        public List<Column> columns = new List<Column>();
        @AuraEnabled
        public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        @AuraEnabled
        public String emptyMessage = 'No rows for the selected scope.';

        public Table(String key, String title, String subtitle) {
            this.key = key;
            this.title = title;
            this.subtitle = subtitle;
        }

        public Table col(String key, String label, String type) {
            columns.add(new Column(key, label, type));
            return this;
        }

        /** A column rendered as a link to the record whose Id is in row[idKey]. */
        public Table link(String key, String label, String idKey) {
            Column c = new Column(key, label, 'link');
            c.idKey = idKey;
            columns.add(c);
            return this;
        }
    }

    public class Column {
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String label;
        /** text | link | currency | percent | number | ratio | status | date | hours | score */
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String idKey;

        public Column(String key, String label, String type) {
            this.key = key;
            this.label = label;
            this.type = type;
        }
    }

    public class Signal {
        /** good | warn | bad | info */
        @AuraEnabled
        public String severity;
        @AuraEnabled
        public String message;

        public Signal(String severity, String message) {
            this.severity = severity;
            this.message = message;
        }
    }

    public static String evaluate(Decimal value, Decimal target, String direction, Decimal warnBand) {
        if (value == null || target == null) {
            return STATUS_NEUTRAL;
        }
        Decimal band = (warnBand == null ? 0.1 : warnBand) * target.abs();
        if (direction == 'lower') {
            if (value <= target) {
                return STATUS_GOOD;
            }
            return value <= target + band ? STATUS_WARN : STATUS_BAD;
        }
        if (value >= target) {
            return STATUS_GOOD;
        }
        return value >= target - band ? STATUS_WARN : STATUS_BAD;
    }

    /** Plain-text formatting used in signals and AI prompts (the LWC formats its own). */
    public static String formatValue(Decimal value, String format) {
        if (value == null) {
            return 'n/a';
        }
        if (format == 'currency') {
            Decimal a = value.abs();
            String sign = value < 0 ? '-' : '';
            if (a >= 1000000) {
                return sign + '$' + a.divide(1000000, 2).format() + 'M';
            }
            if (a >= 10000) {
                return sign + '$' + a.divide(1000, 0).format() + 'K';
            }
            return sign + '$' + a.setScale(0).format();
        }
        if (format == 'percent') {
            return value.setScale(1).format() + '%';
        }
        if (format == 'ratio') {
            return value.setScale(2).format() + 'x';
        }
        if (format == 'months') {
            return value.setScale(1).format() + ' mo';
        }
        if (format == 'days') {
            return value.setScale(0).format() + ' days';
        }
        if (format == 'hours') {
            return value.setScale(0).format() + ' hrs';
        }
        if (format == 'score') {
            return value.setScale(2).format();
        }
        return value.setScale(value.abs() < 10 ? 1 : 0).format();
    }

    /** Safe division returning null when the denominator is zero or null. */
    public static Decimal ratio(Decimal numerator, Decimal denominator) {
        if (numerator == null || denominator == null || denominator == 0) {
            return null;
        }
        return numerator / denominator;
    }

    /** Safe percentage (0-100) returning null when the denominator is zero or null. */
    public static Decimal pct(Decimal numerator, Decimal denominator) {
        Decimal r = ratio(numerator, denominator);
        return r == null ? null : (r * 100).setScale(1);
    }

    /** Sorts rows descending by a numeric key (nulls last). */
    public static void sortRows(List<Map<String, Object>> rows, String key) {
        List<RowSorter> sorters = new List<RowSorter>();
        for (Map<String, Object> r : rows) {
            sorters.add(new RowSorter(r, key, true));
        }
        sorters.sort();
        rows.clear();
        for (RowSorter rs : sorters) {
            rows.add(rs.row);
        }
    }

    /** Sorts rows ascending by a numeric key (nulls last). */
    public static void sortRowsAscending(List<Map<String, Object>> rows, String key) {
        List<RowSorter> sorters = new List<RowSorter>();
        for (Map<String, Object> r : rows) {
            sorters.add(new RowSorter(r, key, false));
        }
        sorters.sort();
        rows.clear();
        for (RowSorter rs : sorters) {
            rows.add(rs.row);
        }
    }

    public static List<Map<String, Object>> first(List<Map<String, Object>> rows, Integer n) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Integer i = 0; i < Math.min(n, rows.size()); i++) {
            result.add(rows[i]);
        }
        return result;
    }

    public class RowSorter implements Comparable {
        public Map<String, Object> row;
        private Decimal value;
        private Boolean descending;

        public RowSorter(Map<String, Object> row, String key, Boolean descending) {
            this.row = row;
            Object v = row.get(key);
            this.value = v == null ? null : Decimal.valueOf(String.valueOf(v));
            this.descending = descending;
        }

        public Integer compareTo(Object other) {
            Decimal o = ((RowSorter) other).value;
            if (value == o) {
                return 0;
            }
            if (value == null) {
                return 1;
            }
            if (o == null) {
                return -1;
            }
            Integer c = value < o ? -1 : 1;
            return descending ? -c : c;
        }
    }
}
