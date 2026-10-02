({
	loadMetrics : function(component,event) {
		var action = component.get("c.getMetrics");
        var restRequest = event.getParam("restRequestJson");
        component.set("v.restRequest",restRequest);
        action.setParams({restRequestJson : JSON.stringify(restRequest)});
		action.setCallback(this, function(a) {
            var result = a.getReturnValue();
            component.set("v.metricsWrapper",result);
            
            var eventParms = { "leadJson" : result.newLead };
            var leadEvent = $A.get("e.c:HealthCheckUpdateLeadMetricsEvent");
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