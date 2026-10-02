({
	doInit : function(component, event, helper) {
		helper.doInit(component,helper);
	}
	,closeModal : function(component,event,helper) {
        var modal = component.find("errorModal");
        $A.util.addClass(modal,'slds-hide');
    }
})