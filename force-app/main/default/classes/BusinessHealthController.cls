/**
 * @group BusinessHealth
 *
 * @description Entry point for the businessHealthPage LWC: builds any Business Health
 * page by key, and supplies the filter options (practices, page list, default as-of
 * date). Read-only and cacheable; the AI Advisor (BusinessHealthAdvisor) is separate
 * because it calls out and writes its cache.
 */
public with sharing class BusinessHealthController {
    /** Navigation order in the UI (Apex map iteration order is not guaranteed). */
    public static final List<String> PAGE_ORDER = new List<String>{ 'leadership', 'sales', 'finance', 'capacity', 'delivery', 'portfolio', 'marketing', 'people' };

    /** Page key -> builder class. */
    public static final Map<String, Type> BUILDERS = new Map<String, Type>{
        'leadership' => BusinessHealthLeadershipPage.class,
        'sales' => BusinessHealthSalesPage.class,
        'finance' => BusinessHealthFinancePage.class,
        'capacity' => BusinessHealthCapacityPage.class,
        'delivery' => BusinessHealthDeliveryPage.class,
        'portfolio' => BusinessHealthPortfolioPage.class,
        'marketing' => BusinessHealthMarketingPage.class,
        'people' => BusinessHealthPeoplePage.class
    };

    /** Page key -> navigation label and Lightning tab API name. */
    public static final Map<String, List<String>> NAV = new Map<String, List<String>>{
        'leadership' => new List<String>{ 'Leadership', 'Business_Health_Leadership' },
        'sales' => new List<String>{ 'Sales & Pipeline', 'Business_Health_Sales' },
        'finance' => new List<String>{ 'Financial', 'Business_Health_Finance' },
        'capacity' => new List<String>{ 'Utilization & Capacity', 'Business_Health_Capacity' },
        'delivery' => new List<String>{ 'Delivery', 'Business_Health_Delivery' },
        'portfolio' => new List<String>{ 'Client Portfolio', 'Business_Health_Portfolio' },
        'marketing' => new List<String>{ 'Marketing', 'Business_Health_Marketing' },
        'people' => new List<String>{ 'People', 'Business_Health_People' }
    };

    public class NavItem {
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String tabName;
    }

    public class Option {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
    }

    public class FilterOptions {
        @AuraEnabled
        public List<Option> practices = new List<Option>();
        @AuraEnabled
        public List<NavItem> pages = new List<NavItem>();
        @AuraEnabled
        public Date defaultAsOfDate;
        @AuraEnabled
        public Boolean asOfIsStale;
        @AuraEnabled
        public Boolean aiEnabled;
    }

    @AuraEnabled(cacheable=true)
    public static BusinessHealthModel.HealthPage getPage(String pageKey, Date asOfDate, String practiceId) {
        try {
            return buildPage(pageKey, BusinessHealthContext.build(asOfDate, practiceId));
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        try {
            FilterOptions o = new FilterOptions();
            for (pse__Practice__c p : [SELECT Id, Name FROM pse__Practice__c WITH USER_MODE ORDER BY Name]) {
                Option opt = new Option();
                opt.value = p.Id;
                opt.label = p.Name;
                o.practices.add(opt);
            }
            for (String key : PAGE_ORDER) {
                NavItem n = new NavItem();
                n.key = key;
                n.label = NAV.get(key)[0];
                n.tabName = NAV.get(key)[1];
                o.pages.add(n);
            }
            o.defaultAsOfDate = BusinessHealthContext.defaultAsOfDate();
            o.asOfIsStale = o.defaultAsOfDate != Date.today();
            Business_Health_Setting__mdt s = BusinessHealthContext.loadSettings();
            o.aiEnabled = s.AI_Enabled__c;
            return o;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    public static BusinessHealthModel.HealthPage buildPage(String pageKey, BusinessHealthContext ctx) {
        Type builderType = BUILDERS.get(pageKey);
        if (builderType == null) {
            throw new IllegalArgumentException('Unknown Business Health page: ' + pageKey);
        }
        BusinessHealthModel.HealthPage page = ((BusinessHealthPageBuilder) builderType.newInstance()).build(ctx);
        page.asOfDate = ctx.asOfDate;
        page.asOfDefaulted = ctx.asOfDefaulted;
        page.scopeLabel = ctx.scopeLabel();
        page.goalSetLabel = ctx.goalSetLabel();
        page.goalSetId = ctx.goalSetId();
        return page;
    }

    private static AuraHandledException auraError(Exception e) {
        String message = e.getMessage() + (e.getTypeName() == 'System.IllegalArgumentException' ? '' : ' (' + e.getTypeName() + ')');
        AuraHandledException ae = new AuraHandledException(message);
        ae.setMessage(message);
        return ae;
    }
}
