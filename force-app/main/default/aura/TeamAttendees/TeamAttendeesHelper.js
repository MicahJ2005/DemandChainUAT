({
	doInit : function(component) {        
        var action = component.get("c.getAttendees");
        action.setParams({recordId : component.get("v.recordId")});
          action.setCallback(this,function(a){
            var returnVal = a.getReturnValue();
            component.set("v.attendees",returnVal);
        });
        $A.enqueueAction(action);
	}
})