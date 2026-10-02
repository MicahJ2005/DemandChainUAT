({
	doInit : function(component,event) {
		var action = component.get("c.loginUsernamePasswordFlow");
		action.setParams({recordId:component.get("v.recordId")});
		action.setCallback(this,function(a){
			var restRequest = a.getReturnValue();
			var restRequestResult = JSON.parse(restRequest);

			//show error modal if there was an error.
			if(!restRequestResult.isSuccessful){
				component.set("v.restRequest",restRequestResult);
				var modal = component.find("errorModal");
				$A.util.removeClass(modal,"slds-hide");
				component.set("v.isLoggedIn",false);
			}else{
				component.set("v.restRequest",restRequestResult);
				component.set("v.isLoggedIn",true);
				var loginEvent = $A.get("e.c:HealthCheckLoginEvent");
				debugger;
		        loginEvent.setParams({ "restRequestJson" : restRequestResult });
		        loginEvent.fire();
	    	}
		});
		$A.enqueueAction(action);
	}
})