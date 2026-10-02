({
	doInit : function(component,event) {
		var restRequest = event.getParam("restRequestJson");
        var action = component.get("c.getOrgWideCodeCoverage");
		action.setParams({restRequestJson : JSON.stringify(restRequest)})
		action.setCallback(this,function(a){
			component.set("v.percentCovered",a.getReturnValue());
		});
		$A.enqueueAction(action);
	}
})