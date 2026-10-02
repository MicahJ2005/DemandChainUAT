/**
* @File Name          : SCCalloutMock.cls
* @Description        :
* @Author             : James Loghry (Demand Chain)
* @Group              :
* @Last Modified By   : James Loghry (Demand Chain)
* @Last Modified On   : 05-04-2021
* @Modification Log   :
*==============================================================================
* Ver         Date                     Author      		      Modification
*==============================================================================
* 1.0    7/16/2019, 6:01:21 PM   James Loghry (Demand Chain)     Initial Version
**/
@isTest
public class CalloutMock implements HttpCalloutMock {
    private List<MockResponse> responses { get; set; }

    public CalloutMock(List<MockResponse> responses){
        System.debug('responses: ' + responses);
        this.responses = responses;
    }

    CalloutMock(){
        System.debug('default constructor');
    }

    // Implement this interface method
    public HTTPResponse respond(HTTPRequest req){
        System.debug('JWL: in mock respond. req: ' + req);
        MockResponse mockResponse = this.responses.get(0);
        this.responses.remove(0);

        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(mockResponse.response);
        System.debug('status code: ' + mockResponse.statusCode);
        res.setStatusCode(mockResponse.statusCode);
        return res;
    }

    public class MockResponse{
        public Integer statusCode { get; set; }
        public String response { get; set; }
        public MockResponse(Integer statusCode, String response) {
            this.statusCode = statusCode;
            this.response = response;
        }
    }
}