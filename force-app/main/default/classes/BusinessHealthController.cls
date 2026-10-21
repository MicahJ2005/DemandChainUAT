/**
 * @group BusinessHealth
 *
 * @description Entry point for the businessHealthPage LWC: builds any Business Health
 * page by key, and supplies the filter options (practices, page list, default as-of
 * date). Read-only and cacheable; the AI Advisor (BusinessHealthAdvisor) is separate
 * because it calls out and writes its cache.
 *
 * Two kinds of page share this engine: the firm-level pages, and the personal My Work
 * views (keys prefixed 'my-'), which are always built for the running user - the client
 * cannot ask for someone else's. Access to both is enforced here (BusinessHealthAccess).
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
        'people' => BusinessHealthPeoplePage.class,
        'my-ae' => MyWorkAccountExecutivePage.class,
        'my-architect' => MyWorkSolutionArchitectPage.class,
        'my-pm' => MyWorkProjectManagerPage.class,
        'my-consultant' => MyWorkConsultantPage.class,
        'my-finance' => MyWorkFinancePage.class
    };

    public static final String MODE_MY_WORK = 'mywork';

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
        @AuraEnabled
        public String description;
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
        /** 'business' or MODE_MY_WORK. */
        @AuraEnabled
        public String mode;
        /** Running user's first name (My Work greeting). */
        @AuraEnabled
        public String firstName;
    }

    /**
     * @param view BusinessHealthModel.VIEW_BRIEF for the page's abbreviated view (pages
     * without one return the full view); anything else returns the full view
     */
    @AuraEnabled(cacheable=true)
    public static BusinessHealthModel.HealthPage getPage(String pageKey, Date asOfDate, String practiceId, String view) {
        try {
            BusinessHealthModel.HealthPage page = buildPage(pageKey, contextFor(pageKey, asOfDate, practiceId));
            return view == BusinessHealthModel.VIEW_BRIEF ? page.abbreviate() : page;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /**
     * @param mode MODE_MY_WORK for the running user's My Work views (only those their
     * permission sets grant); anything else for the firm-level pages
     */
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions(String mode) {
        try {
            FilterOptions o = new FilterOptions();
            o.mode = mode == MODE_MY_WORK ? MODE_MY_WORK : 'business';
            if (o.mode == MODE_MY_WORK) {
                for (List<String> v : BusinessHealthAccess.grantedMyWorkViews()) {
                    NavItem n = new NavItem();
                    n.key = v[0];
                    n.label = v[1];
                    n.description = v[3];
                    o.pages.add(n);
                }
                o.firstName = UserInfo.getFirstName();
            } else {
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

    /**
     * @description The context a page is built in. My Work pages are always scoped to the
     * running user (with their personal goals) and ignore the practice filter; firm pages
     * use the requested practice. Checks access first, before any data is read.
     */
    public static BusinessHealthContext contextFor(String pageKey, Date asOfDate, String practiceId) {
        BusinessHealthAccess.assertAccess(pageKey);
        return BusinessHealthAccess.isMyWork(pageKey)
            ? BusinessHealthContext.buildForUser(asOfDate, UserInfo.getUserId())
            : BusinessHealthContext.build(asOfDate, practiceId);
    }

    public static BusinessHealthModel.HealthPage buildPage(String pageKey, BusinessHealthContext ctx) {
        BusinessHealthAccess.assertAccess(pageKey);
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
        Boolean plain = e instanceof IllegalArgumentException || e instanceof BusinessHealthAccess.NoAccessException;
        String message = e.getMessage() + (plain ? '' : ' (' + e.getTypeName() + ')');
        AuraHandledException ae = new AuraHandledException(message);
        ae.setMessage(message);
        return ae;
    }
}
