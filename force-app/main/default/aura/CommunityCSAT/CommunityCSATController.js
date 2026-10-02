({
    init : function (component, event, helper) {
       
        var surveyId = component.get("v.surveyRecordId");
        var flowDevName = component.get("v.flowDevName");
       
        var flow = component.find("CSAT_Wizard_Container");
        var inputVariables = [
            { 
                name : "surveyId", 
                type : "String", 
                value : surveyId
            }  
        ];
        flow.startFlow(flowDevName, inputVariables);
    },
})