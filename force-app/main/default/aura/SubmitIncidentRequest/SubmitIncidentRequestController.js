({
    init: function (component, event, helper) {
        // Initialize the flow
        var flow = component.find("flowData");
        var flowName = "Case_New_Internal_Request_Case"; // Replace with your flow's API name
        flow.startFlow(flowName);
    },

    handleStatusChange: function (component, event, helper) {
        if (event.getParam("status") === "FINISHED") {
            // Close the flow interface
            $A.get("e.force:closeQuickAction").fire();
        }
    }
})