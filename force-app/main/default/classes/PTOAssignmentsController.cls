public class PTOAssignmentsController{
    public Id resourceId;
    public Id getResourceId(){ return resourceId; }
    public void setResourceId(Id r){  
        resourceId = r;
        getPtoStartDate();    
    }
    
    public Date ptoStartDate;
    public Date getPtoStartDate(){ return ptoStartDate; }
    public void setPtoStartDate(Date s){
        ptoStartDate = s;
        getPtoEndDate();
    }
    
    public Date ptoEndDate;
    public Date getPtoEndDate(){ return ptoEndDate; }
    public void setPtoEndDate(Date e){
        ptoEndDate = e;
        PTOAssignmentsController();     
    }

  
    public Project[] Projects { get; set; }    
    public void PTOAssignmentsController(){ 
        if(resourceID != null && ptoStartDate != null && ptoEndDate != null){
            Date weekStart = ptoStartDate.toStartofWeek();
            System.debug(weekStart);
            Date weekEnd   = ptoEndDate.toStartofWeek().addDays(7);
            System.debug(weekEnd);
            System.debug(resourceId);
            AggregateResult [] results = [SELECT SUM(pse__Estimated_Hours__c) sum,
                                          		 pse__Project__r.Name name,
                                          		 pse__Project__r.pse__Project_Manager__r.Name manager
                                            FROM pse__Est_Vs_Actuals__c
                                           WHERE pse__Resource__r.pse__Salesforce_User__c = :resourceId
                                             AND pse__Start_Date__c >= :weekStart 
                                             AND pse__End_Date__c <= :weekEnd
            							GROUP BY pse__Project__r.Name, pse__Project__r.pse__Project_Manager__r.Name];  
            
            system.debug(results);
            Projects = new List<Project>();
            for (AggregateResult ar : results){
            	Projects.add(new Project (ar));
            } 
        }        
    }
    // wrapper class to hold aggregate data
    public class Project {
        public Decimal Hours { get; private set; }
        public String Name { get; private set; }
        public String Manager { get; private set; }
        
        public Project(AggregateResult ar) {
            Hours   = (Decimal) ar.get('sum');
            Name    = (String) ar.get('name');
            Manager = (String) ar.get('manager');         
        }
    }       
}