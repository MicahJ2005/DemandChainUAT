/**
 * @description       : 
 * @author            : James Loghry (Demand Chain)
 * @group             : 
 * @last modified on  : 05-12-2021
 * @last modified by  : James Loghry (Demand Chain)
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   05-07-2021   James Loghry (Demand Chain)   Initial Version
**/
@istest
public with sharing class BitbucketCalloutTest {

    static testmethod void testCreateSchedule(){
        Test.setMock(
            HttpCalloutMock.class,
            new CalloutMock(
                new List<CalloutMock.MockResponse>{
                    new CalloutMock.MockResponse(200,'')
                }
            )
        );
        Test.startTest();
        BitbucketCallout bbc = new BitbucketCallout();
        bbc.createSchedule('repo','0 6 0 ? * TUE-SAT *');
        Test.stopTest();
    }

    static testmethod void testCreateFork(){
        Test.setMock(
            HttpCalloutMock.class,
            new CalloutMock(
                new List<CalloutMock.MockResponse>{
                    new CalloutMock.MockResponse(200,'')
                }
            )
        );
        Test.startTest();
        BitbucketCallout bbc = new BitbucketCallout();
        bbc.createFork('repo');
        Test.stopTest();
    }

    static testmethod void testCreatePipelineVariable(){
        Test.setMock(
            HttpCalloutMock.class,
            new CalloutMock(
                new List<CalloutMock.MockResponse>{
                    new CalloutMock.MockResponse(200,'')
                }
            )
        );
        Test.startTest();
        BitbucketCallout bbc = new BitbucketCallout();
        bbc.createPipelineVariable('repo','var','val');
        Test.stopTest();
    }

    static testmethod void testCreateBranch(){
        Test.setMock(
            HttpCalloutMock.class,
            new CalloutMock(
                new List<CalloutMock.MockResponse>{
                    new CalloutMock.MockResponse(200,'{}')
                }
            )
        );
        Test.startTest();
        BitbucketCallout bbc = new BitbucketCallout();
        bbc.createBranch('repo','branch');
        Test.stopTest();
    }

    static testmethod void testEnablePipeline(){
        Test.setMock(
            HttpCalloutMock.class,
            new CalloutMock(
                new List<CalloutMock.MockResponse>{
                    new CalloutMock.MockResponse(200,'{}')
                }
            )
        );
        Test.startTest();
        BitbucketCallout bbc = new BitbucketCallout();
        bbc.enablePipeline('repo', true);
        Test.stopTest();
    }
}