({
	init : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
        var navEvt = $A.get("e.force:navigateToSObject");
		navEvt.setParams({
		  "recordId": component.get("v.recId"),
		  "slideDevName": "related"
		});
		navEvt.fire(); 
	   $A.get('e.force:refreshView').fire();
        
	}
    
})