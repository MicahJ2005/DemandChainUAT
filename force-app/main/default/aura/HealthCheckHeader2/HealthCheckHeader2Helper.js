({
	doInit : function(component,event) {
		//loop through http params to get the code parameter.
    	var httpParams = {};
		window.location.search.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(m,key,value) {
      		httpParams[key] = value;
    	});
    	var code =  httpParams["code"];
    	var state = httpParams["state"];

    	//If we haven't signed in yet, then make a token request (e.g. 2nd step in oauth 2 flow).
		if(typeof code !== 'undefined' && code !== null){
			//Check to see that we aren't trying to re-authenticate with an old code.
			var rr = component.get("v.restRequest");
			if(rr !== null && typeof rr !== 'undefined' && rr.access_token !== null && typeof rr.access_token !== 'undefined'){
				return;
			}

			component.set("v.code",code);
 			var action = component.get("c.getAccessToken");
 			action.setParams({environment : state,code : code});
			action.setCallback(this, function(a) {
				var retVal = a.getReturnValue();
                if(retVal !== null){
                    var result = JSON.parse(retVal);

                    component.set("v.restRequest",result);
                    component.set("v.isLoggedIn",true);
                    var loginEvent = $A.get("e.c:HealthCheckLoginEvent");
                    loginEvent.setParams({ "restRequestJson" : result });
                    loginEvent.fire();
                }
			});
			$A.enqueueAction(action);
		}
	}
    ,loginHelper : function(component,environment){
        //Login, to ask for approval (e.g. first step in oauth 2 web server flow)
    	var action = component.get("c.loginViaOAuth");
        action.setParams({environment : environment,customUrl : component.get("v.customUrl")});
		action.setCallback(this, function(a) {
            if(a.getState() === "SUCCESS"){
				var retVal = a.getReturnValue();
				if(retVal.isSuccessful){
					if (window.location.replace){
						window.location.replace(retVal.url);
					} else {
						window.location.href = retVal.url;
					}
				}
			}
		});
        $A.enqueueAction(action);
    }
    ,closePrivacyModal : function(component,event){
        var modal = component.find("privacyModal");
        $A.util.addClass(modal,"slds-hide");
    }
})