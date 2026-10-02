public class MetricController {
    
    private Map<Id, Contact> mapResources = new Map<Id, Contact>();
    public Map<Id, hClsResource> mapUtilization {get;set;}

    public MetricController() {
        mapUtilization = new Map<Id, hClsResource>();
        //fillForecast();
    }
    
    //public void fillForecast() {
        
    //    for(Contact objCon : [SELECT Id, pse__Salesforce_User__c, Name, DCS_Billable_Goal__c FROM Contact WHERE pse__Salesforce_User__r.IsActive = TRUE AND DCS_Billable_Goal__c > 0 ORDER BY Name ASC]) {
    //        mapResources.put(objCon.pse__Salesforce_User__c, objCon);
    //    }
        
    //    // Seed Final Map
    //    for(Id objId : mapResources.keySet()) {
            
    //        // Spin up hClsResource
    //        hClsResource clsResource = new hClsResource(mapResources.get(objId));

    //        // Seed it with Weeks (to keep date grid true)
    //        Date dteNow = System.Today().toStartOfWeek();
    //        Date dteStart = dteNow.addDays(-21);

    //        for(Integer i = 0; i<=12; i++) {
    //            clsResource.mapUtil.put(dteStart, new Map<String, hClsUtilization>());
    //            dteStart = dteStart.addDays(7);
    //            System.Debug(mapResources.get(objId).Name + ' adding: ' + dteStart);
    //        }

    //        mapUtilization.put(objId, clsResource);

    //    }
        
    //    List<DCSUtilizationLine__c> lstEstimatedLines = [
    //        SELECT 
    //            DCSUtilization__r.Id,
    //            DCSUtilization__r.Project__c, 
    //            DCSUtilization__r.Project__r.Name, 
    //            DCSUtilization__r.Opportunity__c, 
    //            DCSUtilization__r.Opportunity__r.Name, 
    //            DCSUtilization__r.Owner.Id, 
    //            DCSUtilization__r.Owner.Name,
    //            DCSUtilization__r.UtilizationName__c,
    //            Hours__c, 
    //            StartofWeek__c 
    //        FROM 
    //            DCSUtilizationLine__c
    //        WHERE
    //            StartofWeek__c = LAST_N_DAYS:21 
    //            OR StartofWeek__c = NEXT_N_DAYS:56 
    //            OR StartofWeek__c = THIS_WEEK
    //        ORDER BY
    //            DCSUtilization__r.Owner.Id,
    //            StartofWeek__c
    //    ];
        
    //    List<pse__Timecard_Header__c> lstActual = [
    //        SELECT 
    //        	pse__Project__c, 
    //            pse__Milestone__r.Name,
    //        	pse__Project__r.Name, 
    //        	pse__Project__r.pse__Opportunity__c, 
    //        	pse__Project__r.pse__Opportunity__r.Name, 
    //        	pse__Resource__r.pse__Salesforce_User__c,
    //        	pse__Total_Hours__c, 
    //        	pse__Start_Date__c 
    //       	FROM 
    //        	pse__Timecard_Header__c 
    //        WHERE 
    //        	(
    //                pse__Billable__c = true 
    //             	OR pse__Project__r.Name LIKE '%PTO%'
    //            )
    //            AND 
    //        	(
				//	pse__Start_Date__c = LAST_N_DAYS:21 
    //                OR pse__Start_Date__c = NEXT_N_DAYS:56 
    //                OR pse__Start_Date__c = THIS_WEEK
    //            )
    //        	AND pse__Resource__r.pse__Salesforce_User__c IN :mapResources.keySet()
    //        	AND pse__Submitted__c = true
    //       	ORDER BY
    //        	pse__Resource__r.pse__Salesforce_User__r.Id,
    //        	pse__Start_Date__c
            	
            	
    //    ];

    //    // Loop through Lines
    //    for(DCSUtilizationLine__c objLine : lstEstimatedLines) {

    //        // Set Initial Variables
    //        String strId = objLine.DCSUtilization__r.Owner.Id;
    //        String strKey = string.valueOf(objLine.DCSUtilization__r.Opportunity__c) + string.valueOf(objLine.DCSUtilization__r.Project__c);
    //        String strAssignment = objLine.DCSUtilization__r.UtilizationName__c;
    //        hClsResource clsResource = mapUtilization.get(strId);

    //        Date dteSunday = objLine.StartofWeek__c;
    //        Double dblHours = objLine.Hours__c;

    //        // Does Week Exist Yet?
    //        if(!clsResource.mapUtil.containsKey(dteSunday)) {
    //            clsResource.mapUtil.put(dteSunday, new Map<String, hClsUtilization>());
    //        }

    //        hClsUtilization clsUtilLine = new hClsUtilization(strKey);
    //        clsUtilLine.strName = strAssignment;
    //        clsUtilLine.dblHoursEst = dblHours;
    //        clsUtilLine.dblHoursAct = null;
    //        clsUtilLine.idForecast = objLine.DCSUtilization__r.Id;

    //        // Create Opp+Proj+Estimated Hours
    //        clsResource.mapUtil.get(dteSunday).put(strKey, clsUtilLine);

    //        // PUT...THE CANDLE...BACK!
    //        mapUtilization.put(strId, clsResource);

    //    }

    //    for(pse__Timecard_Header__c objUtil : lstActual) {

    //        // Set Initial Variables
    //        String strId = objUtil.pse__Resource__r.pse__Salesforce_User__c;
    //        String strKey = string.valueOf(objUtil.pse__Project__r.pse__Opportunity__c) + string.valueOf(objUtil.pse__Project__c);
    //        String strAssignment = objUtil.pse__Project__r.Name + ' ' + objUtil.pse__Milestone__r.Name;
    //        hClsResource clsResource = mapUtilization.get(strId);

    //        // NO LINES
    //        //Date dteSunday = findPreviousSunday(objUtil.pse__Start_Date__c);
    //        Date dteSunday = objUtil.pse__Start_Date__c;
    //        Double dblHours = objUtil.pse__Total_Hours__c;

    //        // Does Week Exist Yet?
    //        if(!clsResource.mapUtil.containsKey(dteSunday)) {
    //            clsResource.mapUtil.put(dteSunday, new Map<String, hClsUtilization>());
    //        }

    //        // Does Opp+Proj Key Exist from Estimation Yet?
    //        if(!clsResource.mapUtil.get(dteSunday).containsKey(strKey)) {
    //            clsResource.mapUtil.get(dteSunday).put(strKey, new hClsUtilization(strKey));
    //        }

    //        hClsUtilization clsUtilLine = clsResource.mapUtil.get(dteSunday).get(strKey);
    //        clsUtilLine.strName = strAssignment;
    //        //clsUtilLine.dblHoursEst = dblHours;
    //        clsUtilLine.dblHoursAct = dblHours;
    //        clsUtilLine.idTimecard = objUtil.Id;

    //        // Create Opp+Proj+Estimated Hours
    //        clsResource.mapUtil.get(dteSunday).put(strKey, clsUtilLine);

    //        // PUT...THE CANDLE...BACK!
    //        mapUtilization.put(strId, clsResource);

    //    }       

    //    System.Debug(JSON.serialize(mapUtilization));
            
    //}
    
    //////////////////////////
    // INNER CLASSES
    //////////////////////////
    public class hClsResource {
        public Contact objResource {get;set;}
        public Map<Date, Map<String, hClsUtilization>> mapUtil {get;set;}
        
        public hClsResource(Contact passResource) {
            objResource = passResource;
            mapUtil = new Map<Date, Map<String, hClsUtilization>>();
        }
    }
   
    public class hClsUtilization {
        public String strKey {get;set;}
        //public Opportunity opUtil {get;set;}
        //public pse__Proj__c opProject {get;set;}
        public Id idForecast {get;set;}
        public Id idTimecard {get;set;}
        public String strName {get;set;}
        public Double dblHoursEst {get;set;}
        public Double dblHoursAct {get;set;}
        
        public hClsUtilization(String passKey) {
            strKey = passKey;
        }
    }
    
}