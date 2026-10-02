({
	getAcctData : function(component, event) {
		var action = component.get("c.getCMData");
		action.setCallback(this, function(response){
			var state = response.getState();
            if(component.isValid() && state === "SUCCESS"){
                component.set("v.cmembers", response.getReturnValue());
            }        
		});
		$A.enqueueAction(action);
	}
})