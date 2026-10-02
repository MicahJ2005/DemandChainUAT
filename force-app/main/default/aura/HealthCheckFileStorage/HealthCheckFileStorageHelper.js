({
	doInit : function(component,event){
		var restRequest = event.getParam("restRequestJson");
        var action = component.get("c.getLimitReport");
		action.setParams({restRequestJson : JSON.stringify(restRequest)})
		action.setCallback(this,function(a){
			component.set("v.limitRpt",a.getReturnValue());
		});
		$A.enqueueAction(action);
	}
})