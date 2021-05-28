@isTest
public class EmailToAnySObjectTest {
    public static Email_to_sObject_Mapping__mdt caseEmailMapping;
    public static void setup(){
        insert new Account(name = 'woolworths');
        caseEmailMapping = [Select sObject_Type__c, Keywords__c, To_Email_Address__c from Email_to_sObject_Mapping__mdt
                                 where sObject_Type__c = 'Case' limit 1];        
    }
    public static testMethod void testCreateServiceRequestFromGenericEmail() 
    {
        setup();
        Messaging.InboundEmail email = new Messaging.InboundEmail() ;
        Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
        email.subject = caseEmailMapping.Keywords__c;
        email.fromAddress = 'nikunj@pq.com';
        email.toAddresses = new List<String>{caseEmailMapping.To_Email_Address__c};
            email.fromName = 'Nikunj Doshi';
        email.plainTextBody = 'test email';
        // add an attachment
        Messaging.InboundEmail.BinaryAttachment attachment = new Messaging.InboundEmail.BinaryAttachment();
        attachment.body = blob.valueOf('my attachment text');
        attachment.fileName = 'textfile.txt';
        attachment.mimeTypeSubType = 'text/plain';
        email.binaryAttachments =
            new Messaging.inboundEmail.BinaryAttachment[] { attachment };
                // add an attachment
                Messaging.InboundEmail.TextAttachment txtattachment = new Messaging.InboundEmail.TextAttachment();
        txtattachment.body = 'my attachment text';
        txtattachment.fileName = 'textfile.txt';
        txtattachment.mimeTypeSubType = 'text/plain';
        email.textAttachments =
            new Messaging.inboundEmail.TextAttachment[] { txtattachment };
                EmailToAnySObject obj = new EmailToAnySObject();
        Test.startTest();
        obj.handleInboundEmail(email, env );
        Test.stopTest();
        List<Contact> testCons = [Select Id from Contact where name ='Nikunj Doshi'];
        system.assert(!testCons.isEmpty());
        List<Case> testCases = [Select Id from Case where contactid =:testCons[0].id];
        //TO BE FIXED system.assert(!testCases.isEmpty());
    }
    
    public static testMethod void testCreateServiceRequestFromGenericEmailLinkToExistingAccount() 
    {
        setup();
        Account pqAcc = new Account(name='pq');
        insert pqAcc;
        Messaging.InboundEmail email = new Messaging.InboundEmail() ;
        Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
        email.subject = ' '+caseEmailMapping.Keywords__c.split(';')[0]+' ';
        email.fromAddress = 'nikunj@pq.com';
        email.toAddresses = new List<String>{caseEmailMapping.To_Email_Address__c};
            email.fromName = 'Nikunj';
        email.plainTextBody = 'test email';
        EmailToAnySObject obj = new EmailToAnySObject();
        Test.startTest();
        obj.handleInboundEmail(email, env );
        Test.stopTest();
        List<Contact> testCons = [Select Id from Contact where email ='nikunj@pq.com'];
        system.assert(!testCons.isEmpty());
        List<Case> testCases = [Select Id from Case where contactid =:testCons[0].id and accountid =:pqAcc.id];
        system.assert(!testCases.isEmpty());
    }
    
    public static testMethod void testCreateServiceRequestFromSpecificEmail() 
    {
        setup();
        Messaging.InboundEmail email = new Messaging.InboundEmail() ;
        Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
        email.subject = caseEmailMapping.Keywords__c;
        email.fromAddress = 'nikunj@pq.com';
        email.toAddresses = new List<String>{caseEmailMapping.To_Email_Address__c};
            //email.fromName = 'Nikunj Doshi';
            email.plainTextBody = 'test email';
        EmailToAnySObject obj = new EmailToAnySObject();
        Test.startTest();
        obj.handleInboundEmail(email, env );
        Test.stopTest();
        List<Contact> testCons = [Select Id from Contact where email ='nikunj@pq.com'];
        system.assert(!testCons.isEmpty());
        List<Case> testCases = [Select Id from Case where contactid =:testCons[0].id];
        //system.assert(!testCases.isEmpty());
    }
}