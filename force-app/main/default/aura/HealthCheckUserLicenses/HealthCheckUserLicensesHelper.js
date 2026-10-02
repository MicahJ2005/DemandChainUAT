({
	loadUserLicenses : function(component,event) {
		var action = component.get("c.getUserLicenses");
        var restRequest = event.getParam("restRequestJson");
        action.setParams({restRequestJson : JSON.stringify(restRequest)});
		action.setCallback(this, function(a) {
            var result = a.getReturnValue();
            component.set("v.userLicenses",result.records);
            
            var eventParms = { "leadJson" : result.newLead };
            var leadEvent = $A.get("e.c:HealthCheckUpdateLeadLicensesEvent");
            leadEvent.setParams(eventParms);
            leadEvent.fire();
		});
		$A.enqueueAction(action);
	}
    ,updateLeadHelper : function(component,event){
        var action = component.get("c.updateLead");
        var lead = event.getParam("leadJson");
        action.setParams({newLead : lead});
		action.setCallback(this, function(a) {
		});
		$A.enqueueAction(action);       
    }
})