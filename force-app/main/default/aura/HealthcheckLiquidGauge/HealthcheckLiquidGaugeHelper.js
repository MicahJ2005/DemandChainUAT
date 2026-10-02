({
	doInit : function(component,event) {
		var svgns = "http://www.w3.org/2000/svg";
        var xlinkns = "http://www.w3.org/1999/xlink";

        var svgroot = document.createElementNS(svgns, "svg");
        svgroot.setAttribute("width", "97%");
        svgroot.setAttribute("height", "200");
        svgroot.setAttribute("id",component.get("v.svgId"));
        var shape = document.createElementNS(svgns, "use");

        //shape.setAttributeNS(xlinkns, "href",component.get("v.pathToResource") + component.get("v.svgPath"));
        svgroot.appendChild(shape);
        var container = component.find("container").getElement();
        container.insertBefore(svgroot, container.firstChild);

        var val = component.get("v.percentValue");
        if(typeof val !== 'undefined' && val !== null){
			var yellow = component.get("v.yellow");
			var red = component.get("v.red");
			var comparison = component.get("v.comparison");

			var config1 = liquidFillGaugeDefaultSettings();


            if(comparison == "pos"){
                if(val <= yellow){
					config1.waveColor = "#FF0000";
				}else if(val <= red){
					config1.waveColor = "#FFFF00";
				}else{
					config1.waveColor = "#00FF00";
				}
            }else if(comparison == "neg"){
                 if(val <= yellow){
					config1.waveColor = "#00FF00";
				}else if(val <= red){
					config1.waveColor = "#FFFF00";
				}else{
					config1.waveColor = "#FF0000";
				}
            }

        	//var gauge1 = loadLiquidFillGauge("fillGauge", 55);
			config1.circleColor = "#942121";
		    //config1.circleColor = "#061c3f";
		    config1.textColor = "#942121";
		    config1.waveTextColor = "#FFFFFF";
		    //config1.waveColor = "#061c3f";
		    config1.circleThickness = 0.02;
		    //config1.textVertPosition = 0.1;
		    config1.waveAnimateTime = 1000;
		    config1.waveHeight = 0.4;
		    config1.waveAnimate = true;
		    config1.waveCount = 5;
		    var svgId = component.get("v.svgId");
		    var gauge1 = loadLiquidFillGauge(svgId, val, config1);
		    //loadLiquidFillGauge(svgId,val,liquidFillGaugeDefaultSettings());
		}
	}
})