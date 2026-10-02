({
	doInit : function(component,event) {
		var action = component.get("c.getCRM");
        var restRequest = event.getParam("restRequestJson");
        action.setParams({restRequestJson : JSON.stringify(restRequest)});
		action.setCallback(this, function(a) {
            component.set("v.crmWrapper",a.getReturnValue());
		});
		$A.enqueueAction(action);
	}
})