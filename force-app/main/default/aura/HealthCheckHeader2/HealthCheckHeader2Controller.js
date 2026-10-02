({
	doInit : function(component, event, helper) {
		helper.doInit(component,helper);
	}
	,openModal : function(component,event,helper){
		var modal = component.find("modal");
		$A.util.removeClass(modal,"slds-hide");
        helper.closePrivacyModal(component,event,helper);
	}
	,closeModal : function(component,event,helper) {
        var modal = component.find("modal");
        $A.util.addClass(modal,'slds-hide');
    }
    ,openPrivacyModal : function(component,event,helper){
        var modal = component.find("privacyModal");
        $A.util.removeClass(modal,"slds-hide");
    }
    ,closePrivacyModal : function(component,event,helper){
        helper.closePrivacyModal(component,event);
    }
    ,loginProduction : function(component,event,helper) {
        helper.loginHelper(component,"Production");
    }
    ,loginSandbox : function(component,event,helper){
        helper.loginHelper(component,"Sandbox");
    }
    ,loginCustom : function(component,event,helper){
        helper.loginHelper(component,component.get("v.customDomain"));
    }
})