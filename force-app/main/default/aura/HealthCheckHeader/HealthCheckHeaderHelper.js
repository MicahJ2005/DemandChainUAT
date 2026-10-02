({
    doInit : function(component,event){
        var recordId = component.get("v.recordId");
        var action = component.get("c.getOrganizationAPIVersion");
		action.setParams({recordId : recordId});
        action.setCallback(this,function(a){
            var result = JSON.parse(a.getReturnValue());
            component.set("v.restRequest",result);
            component.set("v.accountOrg",result.ao);

            var loginEvent = $A.get("e.c:HealthCheckLoginEvent");
	        loginEvent.setParams({ "restRequestJson" : result });
		    loginEvent.fire();
        });
		$A.enqueueAction(action);
    }
    /*,loginProduction : function(component,event){
        this.login('https://login.salesforce.com');
    }
    ,loginSandbox : function(component,event){
        this.login('https://test.salesforce.com');
    }
    ,loginCustom : function(component,event){
        this.login(component.get("v.customDomain"));
    }
    ,closeModal : function(component,event){
        var modal = component.find("modal");
        $A.util.addClass(modal, 'slds-hide');
    }
    ,login : function(endpoint) {
		debugger;
        var action = component.get("c.loginViaOAuth");
        action.setParams({requestEndpoint : endpoint,redirectUri : window.location.pathname)});
		action.setCallback(this, function(a) {
        	debugger;
		});
		$A.enqueueAction(action);
	}*/
})