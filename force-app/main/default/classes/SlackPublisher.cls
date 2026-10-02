/**
 * SlackPublisher
 * @description This class posts messages to Slack utilizing a webhook.
 * Call the postToSlack (invocable method), and pass in one or more messages.  Each message will be sent to all the
 * slack webhooks defined in the Slack_Webhook__mdt custom metadata.
 * Based on the following example: http://coenraets.org/blog/2016/01/slack-salesforce-integration/
 * Repurposed to be more generic.
 * @author James Loghry (Demand Chain Systems)
 * @date 4/5/2018
 *
 * Slack Interactive Messages: https://api.slack.com/interactive-messages
 * Slack Actions / Menus documentation:
 * Slack API Message Builder (Playground): https://api.slack.com/docs/messages/builder
 *
 */
public with sharing class SlackPublisher {

    @InvocableMethod(label='Post to Slack')
    public static void postToSlack(List<SlackNotificationInvocableWrapper> wrappers){
        System.debug('JWL: in post to slack');
       	SlackNotificationInvocableWrapper sniw = wrappers.get(0);

       	SlackNotification sn = new SlackNotification();
       	sn.channel = sniw.channel;
       	sn.username = sniw.username;
       	sn.text = sniw.text;
       	sn.mrkdwn = sniw.mrkdwn;
       	sn = addAttachmentAttribute(sn,'title',sniw.attachmentTitle);
       	sn = addAttachmentAttribute(sn,'title_link',sniw.attachmentTitleLink);
       	sn = addAttachmentAttribute(sn,'pretext',sniw.attachmentPretext);
       	sn = addAttachmentAttribute(sn,'fallback',sniw.attachmentFallback);
       	sn = addAttachmentAttribute(sn,'color',sniw.attachmentColor);
       	sn = addAttachmentAttribute(sn,'author_name',sniw.attachmentAuthorName);
       	sn = addAttachmentAttribute(sn,'author_link',sniw.attachmentAuthorLink);
       	sn = addAttachmentAttribute(sn,'author_icon',sniw.attachmentAuthorIcon);
       	sn = addAttachmentAttribute(sn,'image_url',sniw.attachmentImageUrl);
       	sn = addAttachmentAttribute(sn,'thumb_url',sniw.attachmentThumbUrl);
       	sn = addAttachmentAttribute(sn,'footer',sniw.attachmentFooter);
       	sn = addAttachmentAttribute(sn,'footer_icon',sniw.attachmentFooterIcon);
       	sn = addAttachmentAttribute(sn,'title',sniw.attachmentTitle);
       	sn = addAttachmentAttribute(sn,'ts',sniw.attachmentTs);
       	sn = addAttachmentAttribute(sn,'callback_id',sniw.attachmentCallbackId);
       	sn = addAttachmentAttribute(sn,'title',sniw.attachmentTitle);

        if(!String.isEmpty(sniw.attachmentFieldsJson)){
            if(sn.attachments == null){
                sn.attachments = new List<SlackAttachment>{new SlackAttachment()};
            }
            try{
				sn.attachments.get(0).fields = (List<SlackField>)JSON.deserialize(sniw.attachmentFieldsJson,List<SlackField>.class);
            }catch(Exception e){
                System.debug('JWL: Exception: ' + e.getMessage());
                System.debug('JWL: Exception stack trace: ' + e.getMessage());
            }
        }

        if(!String.isEmpty(sniw.attachmentActionsJson)){
            if(sn.attachments == null){
                sn.attachments = new List<SlackAttachment>{new SlackAttachment()};
            }
            try{
				sn.attachments.get(0).actions = (List<SlackAction>)JSON.deserialize(sniw.attachmentActionsJson,List<SlackAction>.class);
        	}catch(Exception e){
                System.debug('JWL: Exception: ' + e.getMessage());
                System.debug('JWL: Exception stack trace: ' + e.getMessage());
            }
        }

        postToSlack(new List<SlackNotification>{sn});
    }

    public class SlackNotificationInvocableWrapper{
        @InvocableVariable public String channel;
        @InvocableVariable public String username;
        @InvocableVariable public String text;
        @InvocableVariable public boolean mrkdwn;
        @InvocableVariable public String attachmentTitle;
        @InvocableVariable public String attachmentTitleLink;
        @InvocableVariable public String attachmentPretext;
        @InvocableVariable public String attachmentFallback;
        @InvocableVariable public String attachmentColor;
        @InvocableVariable public String attachmentAuthorName;
    	@InvocableVariable public String attachmentAuthorLink;
    	@InvocableVariable public String attachmentAuthorIcon;
    	@InvocableVariable public String attachmentImageUrl;
    	@InvocableVariable public String attachmentThumbUrl;
    	@InvocableVariable public String attachmentFooter;
    	@InvocableVariable public String attachmentFooterIcon;
    	@InvocableVariable public Long attachmentTs;
    	@InvocableVariable public String attachmentCallbackId;
    	@InvocableVariable public String attachmentFieldsJson;
    	@InvocableVariable public String attachmentActionsJson;
    }

    private static SlackNotification addAttachmentAttribute(SlackNotification notification,String field,Object value){
        if(value == null || (value instanceof String && String.isEmpty((String)value))){
            return notification;
        }

        if(notification.attachments == null){
            notification.attachments = new List<SlackAttachment>{new SlackAttachment()};
        }

        SlackAttachment attachment = notification.attachments.get(0);

        String attachmentJson = JSON.serialize(attachment);
        Map<String,Object> attachmentGeneric = (Map<String,Object>)JSON.deserializeUntyped(attachmentJson);
        attachmentGeneric.put(field,value);
        attachmentJson = JSON.serialize(attachmentGeneric);

        notification.attachments.clear();
        System.debug('JWL:----' + attachmentJson + '----');
        notification.attachments.add((SlackAttachment)JSON.deserialize(attachmentJson,SlackAttachment.class));

        return notification;
    }

    //@InvocableMethod(label='Post to Slack')
    public static void postToSlack(List<SlackNotification> notifications) {
        System.debug('JWL: in here... shouldnt be in here, but i am...');
        System.enqueueJob(new QueueableSlackCall(notifications));
    }

    public class SlackNotification{
        @InvocableVariable public String text;
        @InvocableVariable public String username;
        @InvocableVariable public boolean mrkdwn;
        @InvocableVariable public String attachmentsJSON;
        @InvocableVariable public String channel;
        @InvocableVariable public String response_type;
        public List<SlackAttachment> attachments;
    }

    public class SlackAttachment{
        public String title {get; set;}
        public String pretext {get; set;}
        public String text {get; set;}
        public String fallback {get; set;}
        public String color {get; set;}
        public String author_name {get; set;}
        public String author_link {get; set;}
        public String author_icon {get; set;}
        public String title_link {get; set;}
        public String image_url {get; set;}
        public String thumb_url {get; set;}
        public String footer {get; set;}
        public String footer_icon {get; set;}
        public Long ts {get; set;}
        public String callback_id {get; set;}
        public String attachment_type {get; set;}
    	public List<String> mrkdwn_in {get; set;}
        public List<SlackField> fields {get; set;}
        public List<SlackAction> actions {get; set;}
    }

    public class SlackField{
        public String title {get; set;}
        public String value {get; set;}
        public boolean short_x {get; set;}
    }

    public class SlackAction{
        public String type {get; set;}
        public String text {get; set;}
        public String url {get; set;}
        public String style {get; set;}
        public String name {get; set;}
        public String data_source {get; set;}
        public String min_query_length {get; set;}
        public List<SlackOption> options {get; set;}
    }

    /*public class SlackConfirmAction{
        public String title {get; set;}
        public String text {get; set;}
        public String ok_text {get; set;}
        public String dismiss_text {get; set;}
    }*/

    public class SlackOption{
        public String text {get; set;}
        public String value {get; set;}
    }

    public class QueueableSlackCall implements System.Queueable, Database.AllowsCallouts {

        private List<SlackNotification> notifications {get; set;}

        public QueueableSlackCall(List<SlackNotification> notifications) {
            this.notifications = notifications;
        }

        public void execute(System.QueueableContext ctx) {
            List<Slack_Webhook__mdt> webhooks = [Select URL__c From Slack_Webhook__mdt];

            Integer numCallouts = 0;
            for(Slack_Webhook__mdt webhook : webhooks){
                for(SlackNotification notification : notifications){
                    handleSlackArrays(notification);
                    HttpRequest req = new HttpRequest();
            		req.setEndpoint(webhook.URL__c);
            		req.setMethod('POST');

                    System.debug('notification envelope: ' + notification);

                    //Serialize the message envelope as part of the REST request's body.
                    String body = JSON.serialize(notification);
                    body = body.replaceAll('short_x','short');

                    System.debug('JWL: body: ' + body);
            		req.setBody(body);
            		Http http = new Http();

                    //If you want, you can handle the response accordingly, but for now we will just send and forget.
                    HttpResponse res = http.send(req);
                }
            }
        }

        //If any "JSON" variables are populated in the notification hierarchy, then covnert those JSON values to their respective arrays.
        private void handleSlackArrays(SlackNotification notification){
            System.debug('Notification: ' + notification);
            if(!String.isEmpty(notification.attachmentsJSON)){
				System.debug('attachmentsJSON: ' + notification.attachmentsJSON);
                try{
                    notification.attachments = (List<SlackAttachment>)JSON.deserialize(notification.attachmentsJSON,List<SlackAttachment>.class);
                    notification.attachmentsJSON = null;
                }catch(Exception ex){
                    System.debug('Exception: ' + ex.getMessage());
                    System.debug('Exception Stack Trace: ' + ex.getStackTraceString());
                }
            }
        }
    }
}