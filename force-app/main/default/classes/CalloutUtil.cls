/**
 * @File Name          : HBFF_SC_Callout.cls
 * @Description        : Callout utility class for making calls out to mulesoft / named credentials.
 * @Author             : James Loghry (Demand Chain)
 * @Group              :
 * @Last Modified By   : James Loghry (Demand Chain)
 * @Last Modified On   : 05-12-2021
 * @Modification Log   :
 *==============================================================================
 * Ver         Date                     Author      		      Modification
 *==============================================================================
 * 1.0    7/16/2019, 2:31:13 PM   James Loghry (Demand Chain)     Initial Version
 **/
public with sharing abstract class CalloutUtil {
    protected String namedCredential { get; set; }
    protected boolean replaceSpecialChars = true;

    public Integer timeout {get; set;}

  	public CalloutUtil(String namedCredential) {
		this.namedCredential = 'callout:' + namedCredential;
  	}

  	protected abstract String post(String api, String body);

  	protected String post(String api, String body, Map<String,String> headers) {
		return call('POST', api, body, headers);
  	}

    /*protected abstract String get(String api);

  	protected String get(String api, Map<String,String> headers) {
		return call('GET', api, null, headers);
	}

    */
    protected abstract String put(String api, String body);


  	protected String put(String api, String body, Map<String,String> headers) {
        return call('PUT', api, body, headers);
    }/*

  	public Map<String, String> addParameter(Map<String, String> parameters,String key,String value){
		if(!String.isEmpty(key) && !String.isEmpty(value)){
	  		parameters.put(key, value);
		}
		return parameters;
    }

  	public String getParameterString(Map<String, String> parameters) {
		List<String> paramList = new List<String>();
        for(String key : parameters.keySet()){
            String val = parameters.get(key);
            if(!String.isEmpty(val)){
                paramList.add(key + '=' + EncodingUtil.urlEncode(val, 'UTF-8'));
            }
        }
        return String.join(paramList,'&');
  	}*/

    public String replaceSpecialVariables(String str, boolean reverse) {
        if(replaceSpecialChars){
          String result = reverse ? str = str.replace('private', 'private_x') : str.replace('private_x', 'private');
          return reverse ? result = result.replace('type', 'type_x') : result.replace('type_x', 'type');
        }
        return str;
    }

  	private String call(String method, String api, String body, Map<String,String> headers){
		String endpoint = this.namedCredential + api;

		System.debug('endpoint: ' + endpoint);
        System.debug('method: ' + method);

        if(!String.isEmpty(body)){
            body = replaceSpecialVariables(body, false);
            System.debug('body:');
            for(Integer i=0; i < body.length(); i += 100){
                Integer length = i+100;
                if(i+100 > body.length()){
                    length = body.length();
                }
                System.debug(body.substring(i,length));
            }
        }

		HttpRequest req = new HttpRequest();
        req.setTimeout(120000);

        String grantType = req.getHeader('grant_type');
        if(String.isEmpty(grantType) && headers.get('Accept') == null){
            headers.put('Content-Type', 'application/json');
		    headers.put('Accept','application/json');
        }

		for(String header : headers.keySet()){
            System.debug('Header: ' + header + ' = ' + headers.get(header));
            req.setHeader(header,headers.get(header));
        }

        req.setEndpoint(endpoint);
		req.setMethod(method);

        /*if(timeout != null){
            req.setTimeout(timeout);
        }*/

		if(!String.isEmpty(body)){
            req.setBody(body);
		}

        Http http = new Http();

        HTTPResponse res = http.send(req);

		System.debug(JSON.serialize(res.getBody()));
        System.debug('response status: ' + res.getStatus());
        System.debug('response status code: ' + res.getStatusCode());
		if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
			throw new CalloutException(res.getBody());
		}
        System.debug('****** END CALLOUT *****');

        String responseBody = res.getBody();

        if(replaceSpecialChars){
          responseBody = responseBody.replaceAll('\\n(\\s)* ','');
          responseBody = replaceSpecialVariables(responseBody, true);
        }

        System.debug('response body: ' + responseBody);
        if(!String.isEmpty(responseBody)){
            System.debug('body:');
            for(Integer j=0; j < responseBody.length(); j += 100){
                Integer length = j+100;
                if(j+100 > responseBody.length()){
                    length = responseBody.length();
                }
                System.debug(responseBody.substring(j,length));
            }
        }

		return res.getBody();
	}
}