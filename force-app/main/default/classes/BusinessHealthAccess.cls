/**
 * @group BusinessHealth
 *
 * @description Who may see which Business Health page. Access is granted with custom
 * permissions carried by permission sets, not roles or profiles: people here wear several
 * hats (a PM who also bills as a consultant), permission sets stack, and roles drive
 * record sharing, which these views must not change.
 *
 * - Firm-level pages (leadership, sales, ...) need the Business_Health_Viewer permission.
 * - Each My Work view (page key prefix MY_WORK_PREFIX) needs its own permission, and is
 *   always built from the running user's own records.
 *
 * Checked server-side on every page build and AI Advisor call, so granting someone a
 * My Work view never exposes the firm pages through the API.
 */
public with sharing class BusinessHealthAccess {
    public static final String VIEWER = 'Business_Health_Viewer';
    public static final String MY_WORK_PREFIX = 'my-';

    /** My Work views in display order: page key, label, custom permission, summary. */
    public static final List<List<String>> MY_WORK_VIEWS = new List<List<String>>{
        new List<String>{ 'my-ae', 'Account Executive', 'My_Work_Account_Executive', 'Quota, pipeline, accounts and campaign activity' },
        new List<String>{ 'my-architect', 'Solution Architect', 'My_Work_Solution_Architect', 'Deals you support, SOWs and your delivery time' },
        new List<String>{ 'my-pm', 'Project Manager', 'My_Work_Project_Manager', 'Your projects, budgets, approvals and staffing' },
        new List<String>{ 'my-consultant', 'Consultant', 'My_Work_Consultant', 'Your utilization, schedule and timecards' },
        new List<String>{ 'my-finance', 'Finance', 'My_Work_Finance', 'Firm-wide WIP, approvals, billing and cash' }
    };

    /** Lets tests grant permissions without permission set assignments. */
    @TestVisible
    private static Set<String> testGrants;

    public class NoAccessException extends Exception {
    }

    public static Boolean has(String permission) {
        if (testGrants != null) {
            return testGrants.contains(permission);
        }
        return FeatureManagement.checkPermission(permission);
    }

    public static Boolean isMyWork(String pageKey) {
        return pageKey != null && pageKey.startsWith(MY_WORK_PREFIX);
    }

    /** The custom permission a page needs, or null for an unknown My Work key. */
    public static String permissionFor(String pageKey) {
        if (!isMyWork(pageKey)) {
            return VIEWER;
        }
        for (List<String> v : MY_WORK_VIEWS) {
            if (v[0] == pageKey) {
                return v[2];
            }
        }
        return null;
    }

    public static void assertAccess(String pageKey) {
        String permission = permissionFor(pageKey);
        if (permission == null || !has(permission)) {
            throw new NoAccessException(
                isMyWork(pageKey)
                    ? 'You do not have access to this My Work view. Ask your Salesforce admin for the matching My Work permission set.'
                    : 'You do not have access to the Business Health pages. Ask your Salesforce admin for the Business Health Viewer permission set.'
            );
        }
    }

    /** My Work views the running user may see, in display order. */
    public static List<List<String>> grantedMyWorkViews() {
        List<List<String>> granted = new List<List<String>>();
        for (List<String> v : MY_WORK_VIEWS) {
            if (has(v[2])) {
                granted.add(v);
            }
        }
        return granted;
    }
}
