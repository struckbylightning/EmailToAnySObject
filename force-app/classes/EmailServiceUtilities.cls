public class EmailServiceUtilities {
    
    public static String getFromEmail(Messaging.inboundEmail email, String emailField){
        String fieldVal = '';
        if(emailField == 'fromAddress'){
            fieldVal = email.fromAddress;
        }else if(emailField == 'fromName'){
            fieldVal = email.fromName;
        }else if(emailField == 'htmlBody'){
            fieldVal = email.htmlBody;
        }else if(emailField == 'plainTextBody'){
            fieldVal = email.plainTextBody;
        }else if(emailField == 'subject'){
            fieldVal = email.subject;
        }else if(emailField == 'toAddresses'){
            fieldVal = String.join(email.toAddresses, ',');
        }else if(emailField == 'ccAddresses'){
            fieldVal = String.join(email.ccAddresses, ',');
        } 
        return fieldVal;
    }
    
    public static String getAccountNameFromEmail(String fromAddress){
        String accName = '';
        accName = fromAddress.substringBetween('@', '.');
        accName = accName.capitalize();
        //system.debug('accName '+accName);
        return accName;
    }
    
    public static Id doTextLookup(String val, String fieldApiName, String objApiName, Boolean insertMissing, Messaging.inboundEmail email){
        Id lookedupId = null;
        List<sObject> records = new List<sObject>();
        String lookupQuery = 'Select Id, lastmodifieddate, '+fieldApiName+' from '
            + objApiName + ' where '+fieldApiName+'=\''+val+'\' order by lastmodifieddate desc';
        system.debug('lookupQuery '+lookupQuery);
        records = Database.query(lookupQuery);
        if(records.isEmpty()){
            if(insertMissing){
                if(objApiName.equalsIgnoreCase('Contact')){
                    lookedupId = insertMissingContactFromEmail(email);
                }else{
                    Sobject newSobj = Schema.getGlobalDescribe().get(objApiName).newSObject();
                    newSobj.put('name', val);
                    insert newSobj;
                    lookedupId = newSobj.Id;
                }
            }
        }else{
            lookedupId = records[0].Id;
        }
        return lookedupId;
    }
    
    public static Id insertMissingContactFromEmail(Messaging.inboundEmail email){
        Contact senderCont = new Contact();
        String fName = '';
        String lName = '';
        if(email.fromName != null && email.fromName !=''){
            List<String> names = email.fromName.split(' ', 2);
            if(names.size() > 1){
                fName = names[0];
                lName = names[1];
            }
            else{
                lName = names[0];
            }
        }else {
            lName = email.fromAddress.substringBefore('@');
        }
        senderCont.firstName = fName;
        senderCont.lastName = lName==''?'.':lName;
        senderCont.email = /*'test'+*/email.fromAddress;
        senderCont.AccountId = doTextLookup(EmailServiceUtilities.getAccountNameFromEmail(email.fromAddress), 
                                            'Name', 'Account', false, null);
        insert senderCont;
        return senderCont.Id;
    }
    public static List<ContentVersion> createContentVersions(Messaging.InboundEmail email){
        List<ContentVersion> contentVersionsToCreate = new List<ContentVersion>();
        system.debug('email.binaryAttachments '+email.binaryAttachments);
        if(email.binaryAttachments != null){
            for(Messaging.InboundEmail.binaryAttachment binAttach :email.binaryAttachments){
                ContentVersion cv = new ContentVersion();
                cv.VersionData = binAttach.body;
                cv.Title = binAttach.fileName;
                cv.PathOnClient = binAttach.fileName;
                contentVersionsToCreate.add(cv);
            } 
        }
        system.debug('email.textAttachments '+email.textAttachments);
        if(email.textAttachments != null){
            for (Messaging.InboundEmail.textAttachment textAttach :email.textAttachments){
                if(textAttach.body != null){
                    ContentVersion cv = new ContentVersion();
                    String body = textAttach.body.replace('<','');
                    Blob bodyBlob = blob.toPDF('Empty body');
                    try{
                        bodyBlob = blob.toPDF(body);
                    }
                    catch(Exception ex){
                        String message = 'Exception occured - '+ex.getMessage()
                            +' \n Attachment Body:- '+body
                            +'\n\n Stacktrace: ' + ex.getStacktraceString()
                            +'\n\n email.textAttachments '+email.textAttachments;
                        bodyBlob = blob.toPDF('Empty body because of error');
                        
                        EmailServiceUtilities.sendErrorEmail('Exception occured doing toPdf', message);
                    }
                    cv.VersionData = bodyBlob;
                    cv.Title = textAttach.fileName;
                    cv.PathOnClient = textAttach.fileName;
                    contentVersionsToCreate.add(cv);
                }
            } 
        }
        system.debug('contentVersionsToCreate '+contentVersionsToCreate);
        if(!contentVersionsToCreate.isEmpty())
            insert contentVersionsToCreate;
        return contentVersionsToCreate;
    }
    public static List<ContentDocumentLink> createContentDocumentLinks(List<ContentVersion> contentVersions, List<Id> recordsToLink){
        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        for(ContentVersion cv: [select ContentDocumentId from ContentVersion where id = :contentVersions]){
            for(Id recordId: recordsToLink){
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.LinkedEntityId = recordId;
                cdl.ContentDocumentId = cv.ContentDocumentId;
                cdl.ShareType = 'V';
                cdls.add(cdl);
            }
        }
        insert cdls;
        return cdls;
    }
    public static sObject lookupRecordByThreadIdInEmail(String emailText, String Thread_Id_field_name, String sObject_Type){
        String threadId = emailText.substringBetween('[ ', ' ]');
        threadId = '[ ' + threadId + ' ]';
        List<sObject> macthingRecords = new List<sObject>();
        List<String> fieldsToQuery = new List<String>{'Id'};
            if(sObject_Type == 'Case')fieldsToQuery.add('isClosed');
        String recordSearchQuery = 'Select '+ String.join(fieldsToQuery , ',')+ ' from '+ sObject_Type + ' where '+ Thread_Id_field_name +'= \''+ threadId+'\'';
        macthingRecords = Database.query(recordSearchQuery );
        if(!macthingRecords .isEmpty())
            return macthingRecords[0];
        
        //TODO - what is multiple match
        return null;
    }
    /*public static Case lookupCaseByThreadIdInEmail(String emailText){
String threadId = emailText.substringBetween('[ ', ' ]');
List<Case> macthingCases = new List<Case>();
macthingCases = [Select Id, Status, isClosed from Case where thread_id__c =: threadId];
if(!macthingCases.isEmpty())
return macthingCases[0];
return null;
}*/
    public static String limitLength(String text, Integer len){
        if(text==null)
            return'';
        if(text.length() < len) 
            return text;
        return text.left(len);
    } 
    public static Map<String, List<Id>> findLeadContact(List<String> emailAddrs){
        Map<String, List<Id>> emailToIds = new Map<String, List<Id>>();
        List<List<SObject>> results =  [FIND :String.join(emailAddrs, ' OR ') IN email FIELDS RETURNING Lead(email WHERE isConverted = false), Contact(email), User(email)];
        for(List<SObject> objResults :  results){
            for(SObject indvResult : objResults){
                String emailAddr = (String)indvResult.get('email');
                if(!emailToIds.containsKey(emailAddr))emailToIds.put(emailAddr, new List<Id>());
                emailToIds.get(emailAddr).add((Id)indvResult.get('id'));
            }
        }
        return emailToIds;
    }
    public static EmailMessage createEmailMessage(Id caseId, Id relatedToId, Messaging.InboundEmail email) {
        String value;
        Integer maxlength;
        
        List<Id> toIds = new List<Id>();
        List<Id> ccIds = new List<Id>();
        EmailMessage theEmail = new EmailMessage();
        theEmail.status = '0';
        theEmail.ParentId = caseId;
        theEmail.relatedToId = relatedToId;
        theEmail.Incoming = true;
        if(email.Subject != null)
            theEmail.Subject = limitLength(email.Subject,
                                           EmailMessage.Subject.getDescribe().getLength());
        theEmail.MessageDate = datetime.now();
        if(email.htmlBody != null)
            theEmail.HtmlBody = limitLength(email.htmlBody, EmailMessage.HtmlBody.getDescribe().getLength());  
        if(email.plainTextBody != null)
            theEmail.TextBody = limitLength(email.plainTextBody, EmailMessage.TextBody.getDescribe().getLength());
        theEmail.FromName = email.fromName;
        theEmail.FromAddress = email.fromAddress;
        //if(email.ccAddresses != null)
        //    theEmail.CcAddress = limitLength(String.join(email.ccAddresses, ';'), EmailMessage.CcAddress.getDescribe().getLength()); 
        List<String> allEmails = new List<String>();
        if(email.toAddresses != null)allEmails.addAll(email.toAddresses);
        if(email.ccAddresses != null)allEmails.addAll(email.ccAddresses);
        if(email.fromAddress != null)allEmails.add(email.fromAddress);
        Map<String, List<Id>> emailAddrToIds = findLeadContact(allEmails);
        
        if(email.toAddresses != null){
        List<String> toAddrs = new List<String>();
        for(String toAddr: email.toAddresses){
            if(emailAddrToIds.containsKey(toAddr))
                toIds.addAll(emailAddrToIds.get(toAddr));
            else toAddrs.add(toAddr);
        }
        if(toAddrs != null)
            theEmail.toAddress = limitLength(String.join(toAddrs, ';'), EmailMessage.toAddress.getDescribe().getLength());       
         //theEmail.toIds =toIds;
        }
        if(email.ccAddresses != null){
        List<String> ccAddrs = new List<String>();
        for(String ccAddr: email.ccAddresses){
            if(emailAddrToIds.containsKey(ccAddr))
                ccIds.addAll(emailAddrToIds.get(ccAddr));
            else ccAddrs.add(ccAddr);
        }
        if(ccAddrs != null)
            theEmail.CcAddress = limitLength(String.join(ccAddrs, ';'), EmailMessage.CcAddress.getDescribe().getLength()); 
          //theEmail.ccIds = ccIds;
        }
        system.debug('theEmail '+theEmail.Subject);
        insert theEmail;
        Map<String, List<Id>> personAddress = new Map<String, List<Id>>{'ToAddress'=> toIds,
                                  'CcAddress'=> ccIds};
        if(emailAddrToIds.containsKey(email.fromAddress)){
            List<Id> fromAddrIds = emailAddrToIds.get(email.fromAddress);
            personAddress.put('FromAddress', new List<Id>{fromAddrIds[0]}); //can have only one sender
            if(fromAddrIds.size()>1){
                fromAddrIds.remove(0);
                personAddress.put('OtherAddress', fromAddrIds);
            }
        }
//BccAddress
        createEmailMessageRelation(theEmail.Id, personAddress);
        
        return theEmail; 
    }
    public static void createEmailMessageRelation(Id emailMessageId, Map<String, List<Id>> personAddress) {
        List<EmailMessageRelation> emailMsgRelations = new List<EmailMessageRelation>();
        for(String addrType : personAddress.keyset()){
            for(Id personId: personAddress.get(addrType)){
                   EmailMessageRelation emailMsgRelation = new EmailMessageRelation();
                   emailMsgRelation.EmailMessageId = emailMessageId;
                   emailMsgRelation.RelationId = personId;
                   emailMsgRelation.RelationType = addrType;
                   emailMsgRelations.add(emailMsgRelation);
               }
        }
        insert emailMsgRelations;
    }
    public static void sendErrorEmail(String subjectText, String bodyText){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {'nikunj.sfdc@gmail.com'};
            mail.setToAddresses(toAddresses);
        mail.setSubject(subjectText);
        mail.setPlainTextBody(bodyText);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}