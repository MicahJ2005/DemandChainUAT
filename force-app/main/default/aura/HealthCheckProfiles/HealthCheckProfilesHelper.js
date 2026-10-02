({
	doInit : function(component,event) {
		var action = component.get("c.getProfiles");
        var restRequest = event.getParam("restRequestJson");
        action.setParams({restRequestJson : JSON.stringify(restRequest)});
		action.setCallback(this, function(a) {
            component.set("v.permissionSetWrappers",a.getReturnValue());
		});
		$A.enqueueAction(action);
	}
})