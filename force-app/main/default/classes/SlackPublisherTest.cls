/**
 * SlackPublisherTest
 * @description Unit test for SlackPublisher
 * @author James Loghry  (Demand Chain Systems)
 * @date 4/6/2018
 */
@isTest
private class SlackPublisherTest {
    
    
    static testmethod void testInvocable(){
        SlackPublisher.SlackNotificationInvocableWrapper wrapper = new SlackPublisher.SlackNotificationInvocableWrapper();
        wrapper.username = 'test';
        wrapper.channel = 'test';
        wrapper.text = 'test';
        wrapper.mrkdwn = false;
        wrapper.attachmentTitle = 'test';
        wrapper.attachmentPretext = 'test';
        wrapper.attachmentFallback = 'test';
        wrapper.attachmentColor = 'test';
        wrapper.attachmentAuthorName = 'test';
        wrapper.attachmentAuthorLink = 'test';
        wrapper.attachmentAuthorIcon = 'test';
        wrapper.attachmentThumbUrl = 'test';
        wrapper.attachmentImageUrl = 'test';
        wrapper.attachmentFooter = 'test';
        wrapper.attachmentFooterIcon = 'test';
        wrapper.attachmentTitle = 'test';
        wrapper.attachmentTs = 123;
        SlackPublisher.SlackField sf = new SlackPublisher.SlackField();
        sf.title = 'test';
        sf.value = 'test';
        List<SlackPublisher.SlackField> fields = new List<SlackPublisher.SlackField>{sf};
        String fieldsJson = JSON.serialize(fields);
        System.debug('JWL: fieldsJson: ' + fieldsJson);
        
        wrapper.attachmentFieldsJson = fieldsJson;
        wrapper.attachmentActionsJson = '[]';
        
        Test.setMock(HttpCalloutMock.class,new SlackPublisherMock());
        
        Test.startTest();
        SlackPublisher.postToSlack(new List<SlackPublisher.SlackNotificationInvocableWrapper>{wrapper});
        Test.stopTest();
        
    }

    static testmethod void testPostToSlack(){
        
        SlackPublisher.SlackNotification sn = new SlackPublisher.SlackNotification();
        sn.text = 'test';
        sn.username = 'test';
        sn.mrkdwn = true;
        sn.attachments = new List<SlackPublisher.SlackAttachment>();
        
        SlackPublisher.SlackAttachment att = new SlackPublisher.SlackAttachment();
        att.title = 'test';
        att.pretext = 'test';
        att.text = 'test';
        att.fallback = 'test';
        att.color = 'test';
        att.author_name = 'test';
        att.author_link = 'test';
        att.author_icon = 'test';
        att.title_link = 'test';
        att.image_url = 'test';
        att.thumb_url = 'test';
        att.footer = 'test';
        att.footer_icon = 'test';
        att.ts = 123;
        att.callback_id = 'test';
        att.attachment_type = 'test';
        att.mrkdwn_in = new List<String>{'test'};
        
        att.fields = new List<SlackPublisher.SlackField>();
        SlackPublisher.SlackField fld = new SlackPublisher.SlackField();
        fld.short_x = true;
        fld.title = 'test';
        fld.value = 'test';
        att.fields.add(fld);
        
        att.actions = new List<SlackPublisher.SlackAction>();
        SlackPublisher.SlackAction sa = new SlackPublisher.SlackAction();
        sa.data_source = 'test';
        sa.min_query_length = 'test';
        sa.name = 'test';
        
        sa.options = new List<SlackPublisher.SlackOption>();
        SlackPublisher.SlackOption so = new SlackPublisher.SlackOption();
        so.text = 'test';
        so.value = 'test';
        sa.options.add(so);
        
        sa.style = 'test';
        sa.text = 'test';
        sa.type = 'test';
        sa.url = 'test';
        att.actions.add(sa);
        
        sn.attachments.add(att);
        sn.attachmentsJSON = JSON.serialize(sn.attachments);
        
        Test.setMock(HttpCalloutMock.class,new SlackPublisherMock());
        
        Test.startTest();
        SlackPublisher.postToSlack(new List<SlackPublisher.SlackNotification>{sn});
        Test.stopTest();
        
        //Can't really assert much with this class.
    }
    
    static testmethod void testPostToSlackWithException(){
        
        SlackPublisher.SlackNotification sn = new SlackPublisher.SlackNotification();
        sn.text = 'test';
        sn.username = 'test';
        sn.mrkdwn = true;
        sn.attachmentsJson = '{{[';
        
        Test.setMock(HttpCalloutMock.class,new SlackPublisherMock());
        
        Test.startTest();
        SlackPublisher.postToSlack(new List<SlackPublisher.SlackNotification>{sn});
        Test.stopTest();
        
        //Can't really assert much with this class.
    }
}