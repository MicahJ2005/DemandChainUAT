({
	doInit : function(component, event, helper) {
		helper.getAcctData(component, event);
	},
	signin : function(component, event, helper){
		var action = component.get("c.signinCM");
		var cm = event.currentTarget.getAttribute('data-cmID');
		action.setParams({cmid : cm});
		action.setCallback(this, function(response){
			var state = response.getState();
            if(component.isValid() && state === "SUCCESS"){
                helper.getAcctData(component, event);
                var modal = component.find("successmessage");
				$A.util.removeClass(modal,"slds-hide");
            }        
		});
		$A.enqueueAction(action);
	},
	closeModal : function(component, event, helper){
		var modal = component.find("successmessage");
		$A.util.addClass(modal,"slds-hide");
	},
	newReg : function(component, event, helper){
		var modal = component.find("NewReg");
		$A.util.removeClass(modal,"slds-hide");
	},
	register : function(component, event, helper){
		var action = component.get("c.createNew");
		var cFname = component.get("v.FirstName");
		var cLname = component.get("v.LastName");
		var cTitle = component.get("v.Title");
		var cCompany = component.get("v.CompanyName");
		var cEmail = component.get("v.contEmail");

		action.setParams({fname : cFname, lname : cLname, cTitle : cTitle, comp : cCompany, cEmail : cEmail});
		action.setCallback(this, function(response){
			var state = response.getState();
            if(component.isValid() && state === "SUCCESS"){
                helper.getAcctData(component, event);
                var modal = component.find("NewReg");
				$A.util.addClass(modal,"slds-hide");
				var modal2 = component.find("successmessage");
				$A.util.removeClass(modal2,"slds-hide");
            }        
		});
		$A.enqueueAction(action);
	},
	closeRegModal : function(component, event, helper){
		var modal = component.find("NewReg");
		$A.util.addClass(modal,"slds-hide");
	}
})