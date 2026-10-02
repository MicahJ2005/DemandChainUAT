({
	loadApiRequests : function(component,event) {
		var restRequest = event.getParam("restRequestJson");
        var action = component.get("c.getLimitReport");
		action.setParams({restRequestJson : JSON.stringify(restRequest)});
		action.setCallback(this,function(a){
            var returnValue = a.getReturnValue();
			component.set("v.limitRpt",returnValue);
            
            var eventParms = { "leadJson" : returnValue.newLead };
            var leadEvent = $A.get("e.c:HealthCheckUpdateLeadLimitsEvent");
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