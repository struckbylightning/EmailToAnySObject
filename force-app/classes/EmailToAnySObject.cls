global class EmailToAnySObject implements Messaging.InboundEmailHandler {
    /*public static FINAL String GENERAL_QUEUE = 'General Enquiry';
public static FINAL String GENERAL_RECORDTYPE_DEVNAME = 'General_Enquiry';
public static FINAL String GENERAL_PRIORITY = '3';
public static FINAL String DOMAIN_CHECK = 'DOMAIN_CHECK';
public static FINAL String SENDER_EMAIL_ADDRESS = 'SENDER_EMAIL_ADDRESS';
public static FINAL String MISCELLANEOUS = 'MISCELLANEOUS';
public static FINAL String GENERIC_SUPPORT_EMAIL = 'proquesthussmannhelpdesk@gmail.com';
public static FINAL String INTERNAL_EMAIL_DOMAIN = '@xyz.com';
public static FINAL String KEYWORD_DELIMINITER = ';';*/
    public static FINAL String SENDER_EMAIL_ADDRESS = 'SENDER_EMAIL_ADDRESS';
    public static FINAL String KEYWORD_DELIMINITER = ';';
    public static FINAL String SUBJ_AND_BODY = 'Email Subject And Body';
    public static FINAL String SUBJ_ONLY = 'Email Subject';
    public static FINAL String BODY_ONLY = 'Email Body';
    //TODO 1 Fix email config 
    public static Email_to_sObject_Configuration__mdt emailConfig{
        get{
            if(emailConfig == null){
                emailConfig = 
                    [Select Default_Entitlement_Process_Id__c, DOMAIN_CHECK__c, General_Priority__c, 
                     General_Queue_Name__c, General_Recordtype_Devname__c, Generic_Support_Email__c,
                     Internal_Email_Domain__c, MISCELLANEOUS__c,
                     Do_Case_Sensitive_Keywords_Match__c, Do_Keyword_Match_Against__c from
                     Email_to_sObject_Configuration__mdt limit 1];
            }
            return emailConfig;
        }
        set;}
    
    public static List<Email_to_sObject_Mapping__mdt> allsObjMapping{
        get{
            if(allsObjMapping == null){
                allsObjMapping = new List<Email_to_sObject_Mapping__mdt>();
                allsObjMapping = [Select sObject_Type__c, Keywords__c, To_Email_Address__c, Order__c,
                                  Create_Record__c, Log_EmailMessage__c, Thread_Id_Field_API_Name__c,
                                  (Select Field_Value__c, Insert_related_record_if_no_match_found__c,
                                   Field_Config__r.Field_API_Name__c,  
                                   Field_Config__r.Is_Text_Lookup__c,
                                   Field_Config__r.Text_Lookup_Field_API_Name__c,
                                   Field_Config__r.Text_Lookup_sObject_API_Name__c
                                   from Predefined_Field_Values__r) 
                                  from Email_to_sObject_Mapping__mdt order by Order__c asc];
            }
            return allsObjMapping;
        }
        set;
    }
    //Field_Config__r.Is_Date_Field__c, 
    //Field_Config__r.Is_Decimal_Field__c,
    //Field_Config__r.Is_Time_Field__c,
    
    public static Map<String, Map<String, Email_to_sObject_Mapping__mdt>>
        toAddressToKeywordTosObjMappings{
            get{
                if(toAddressToKeywordTosObjMappings == null){
                    toAddressToKeywordTosObjMappings = new Map<String, Map<String, Email_to_sObject_Mapping__mdt>>();
                    for(Email_to_sObject_Mapping__mdt emailToSerReq: allsObjMapping){
                        if(!toAddressToKeywordTosObjMappings.containsKey(emailToSerReq.To_Email_Address__c))
                            toAddressToKeywordTosObjMappings.put(emailToSerReq.To_Email_Address__c, 
                                                                 new Map<String, Email_to_sObject_Mapping__mdt>());
                        Map<String, Email_to_sObject_Mapping__mdt> keywordToMapping =
                            toAddressToKeywordTosObjMappings.get(emailToSerReq.To_Email_Address__c);
                        for(String keyword : emailToSerReq.Keywords__c.split(KEYWORD_DELIMINITER)){
                            keywordToMapping.put(keyword.trim(), emailToSerReq);
                        }
                        toAddressToKeywordTosObjMappings.put(emailToSerReq.To_Email_Address__c, keywordToMapping);
                    }
                }
                return toAddressToKeywordTosObjMappings;
            }set;
        }
    
    public static Email_to_sObject_Mapping__mdt getToAddressToKeywordTosObjMapping(String fromAddress, String toAddress, String emailSubject, String emailBody){
        //system.debug('toAddressToKeywordTosObjMappings '+toAddressToKeywordTosObjMappings);
        //if(fromAddress.contains(emailConfig.Internal_Email_Domain__c ))
        //    toAddress = emailConfig.Generic_Support_Email__c ;
        String matchAgainst = emailConfig.Do_Keyword_Match_Against__c;
        String emailText =
            (matchAgainst == SUBJ_AND_BODY ? emailSubject + ' ' + emailBody : (matchAgainst == SUBJ_ONLY? emailSubject : emailBody ));
        Email_to_sObject_Mapping__mdt relatedMapping = new Email_to_sObject_Mapping__mdt();
        if(toAddressToKeywordTosObjMappings.containsKey(toAddress)){
            Map<String, Email_to_sObject_Mapping__mdt> keywordTosObjMappings
                = toAddressToKeywordTosObjMappings.get(toAddress);
            system.debug('toAddress '+toAddress);
            system.debug('keywordTosObjMappings '+keywordTosObjMappings);
            system.debug('keyset '+keywordTosObjMappings.keyset());
            Set<String> matchingKeywords = new Set<String>();
            for(String keyword: keywordTosObjMappings.keySet()){
                
                if(keyword != emailConfig.MISCELLANEOUS__c){ 
                    if(emailConfig.Do_Case_Sensitive_Keywords_Match__c?
                       emailText.contains(' '+keyword+' '):
                       emailText.containsIgnoreCase(' '+keyword+' '))                
                    {
                        matchingKeywords.add(keyword);
                    }
                }
            }
            system.debug('matchingKeywords '+matchingKeywords);
            if(matchingKeywords.size() == 1){
                relatedMapping = keywordTosObjMappings.get(new List<String>(matchingKeywords)[0]);
            }else{
                if(keywordTosObjMappings.containsKey(emailConfig.MISCELLANEOUS__c))
                    relatedMapping = keywordTosObjMappings.get(emailConfig.MISCELLANEOUS__c);
            }
        }
        return relatedMapping;
    }
    
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email, Messaging.InboundEnvelope env){
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        Email_to_sObject_Mapping__mdt toAddressToKeywordTosObjMapping = new Email_to_sObject_Mapping__mdt();
        sObject newSobjRecord;
        try{
            system.debug('email '+email);
            system.debug('env '+env);
            List<String> matchingQueueToAddreses = new List<String>();
            for(String toAddrQueue: toAddressToKeywordTosObjMappings.keySet()){
                for(String toAddrEmail: email.toAddresses){
                    if(toAddrQueue == toAddrEmail)
                        matchingQueueToAddreses.add(toAddrEmail);
                }
            }
            if(matchingQueueToAddreses != null && matchingQueueToAddreses.size() == 1){
                toAddressToKeywordTosObjMapping = new Email_to_sObject_Mapping__mdt();
                toAddressToKeywordTosObjMapping = getToAddressToKeywordTosObjMapping(email.fromAddress, matchingQueueToAddreses[0], 
                                                                                     email.subject, email.plainTextBody);
                system.debug('toAddressToKeywordTosObjMapping '+toAddressToKeywordTosObjMapping);
            }else {
                //2 TODO - if more than on match found than?
            }
            Boolean createRecord = false;
            if(toAddressToKeywordTosObjMapping.Id != null){  
                String objType = toAddressToKeywordTosObjMapping.sObject_Type__c;
                sObjectType sObjTyp = Schema.getGlobalDescribe().get(toAddressToKeywordTosObjMapping.sObject_Type__c);
                newSobjRecord = sObjTyp.newSObject();
                Map<String, SObjectField> fieldMetadataMap = sObjTyp.getDescribe().fields.getMap();
                if(toAddressToKeywordTosObjMapping.Thread_Id_Field_API_Name__c != null)
                {
                    SObject matchingRecord = EmailServiceUtilities.lookupRecordByThreadIdInEmail(email.subject+ ' '+ email.plainTextBody, 
                                                                                                 toAddressToKeywordTosObjMapping.Thread_Id_Field_API_Name__c, toAddressToKeywordTosObjMapping.sObject_Type__c
                                                                                                );
                    if(matchingRecord != null && matchingRecord.Id != null){
                        newSobjRecord.Id = matchingRecord.Id;
                        //Add a config check for Closed Case behaviour
                        if(toAddressToKeywordTosObjMapping.sObject_Type__c == 'Case' && (Boolean)matchingRecord.get('isClosed')){
                            newSobjRecord.put('parentId', matchingRecord.Id);
                        }
                        
                        //If the object to be instantiated is Case object then locate Case thread id in email subject line,
                        // if present locate the main Case and log email message underneath it.
                    }
                }
                //Create new record
                if(toAddressToKeywordTosObjMapping.Create_Record__c && newSobjRecord.Id == null)
                {  
                    createRecord = true;
                    for(Predefined_Field_Value__mdt preDefalue: toAddressToKeywordTosObjMapping.Predefined_Field_Values__r){
                        String fieldVal = preDefalue.Field_Value__c;
                        String fieldApiName = preDefalue.Field_Config__r.Field_API_Name__c;
                        if(fieldVal.startsWith('{{')){
                            String fieldRef = fieldVal.substringBetween('{{','}}');
                            if(fieldRef.startsWith('email.')){
                                String emailMessageField = fieldRef.substringAfter('email.');
                                fieldVal = EmailServiceUtilities.limitLength(EmailServiceUtilities.getFromEmail(email, emailMessageField),
                                                                             fieldMetadataMap.get(fieldApiName).getDescribe().getLength());
                            }else if(fieldRef.equalsIgnoreCase(emailConfig.DOMAIN_CHECK__c)){
                                fieldVal = EmailServiceUtilities.getAccountNameFromEmail(email.fromAddress);
                            }else if(fieldRef.equalsIgnoreCase(SENDER_EMAIL_ADDRESS)){
                                fieldVal = email.fromAddress;
                            }
                        }
                        if(preDefalue.Field_Config__r.Is_Text_Lookup__c){
                            newSobjRecord.put(fieldApiName,
                                              EmailServiceUtilities.doTextLookup(fieldVal, preDefalue.Field_Config__r.Text_Lookup_Field_API_Name__c,
                                                                                 preDefalue.Field_Config__r.Text_Lookup_sObject_API_Name__c,
                                                                                 preDefalue.Insert_related_record_if_no_match_found__c, email));
                        }else{
                            newSobjRecord.put(fieldApiName, fieldVal);
                        }
                    }
                }
            }
            else{
                createRecord = true;
                Case defaultCase = new Case();
                defaultCase.subject = email.subject;
                defaultCase.Description = email.plainTextBody;
                newSobjRecord =defaultCase;
                /*newSobjRecord.accountId = getMatchingAccountId(emailConfig.DOMAIN_CHECK__c , email.fromAddress);
newSobjRecord.priority = String.valueOf(emailConfig.General_Priority__c);
newSobjRecord.recordTypeId = caseRecordTypeDevNameToId.get(emailConfig.General_Recordtype_Devname__c );
newSobjRecord.ownerId = queueNameToQueueId.get(emailConfig.General_Queue_Name__c ); 
newSobjRecord.accountId = getMatchingAccountId(DOMAIN_CHECK, email.fromAddress);
newSobjRecord.priority = GENERAL_PRIORITY;
newSobjRecord.recordTypeId = caseRecordTypeDevNameToId.get(GENERAL_RECORDTYPE_DEVNAME);
newSobjRecord.ownerId = queueNameToQueueId.get(GENERAL_QUEUE);
*/
            }
            //if(newSobjRecord.get('ownerId') == null)
            //    newSobjRecord.put('ownerId', queueNameToQueueId.get(emailConfig.General_Queue_Name__c));
            if(createRecord && newSobjRecord.id ==null){
                system.debug('newSobjRecord '+newSobjRecord);
                insert newSobjRecord; 
            }
            List<ContentVersion> cvs = EmailServiceUtilities.createContentVersions(email);
            List<Id> recordsToLinkFileWith = new List<Id>{newSobjRecord.Id};
                system.debug('toAddressToKeywordTosObjMapping '+toAddressToKeywordTosObjMapping);
            if(toAddressToKeywordTosObjMapping.Log_EmailMessage__c){
                EmailMessage loggedEmail = new EmailMessage();
                if(newSobjRecord.get('Id') != null){
                    if(toAddressToKeywordTosObjMapping.sObject_Type__c == 'Case')
                    {
                        loggedEmail = EmailServiceUtilities.createEmailMessage((Id)newSobjRecord.get('Id'), null, email);
                    }
                    else{
                        loggedEmail = EmailServiceUtilities.createEmailMessage(null, (Id)newSobjRecord.get('Id'), email);
                    } 
                }else{
                    loggedEmail = EmailServiceUtilities.createEmailMessage(null, null, email);
                }
                //Create email message
                system.debug('log email message');
                recordsToLinkFileWith.add(loggedEmail.Id);
            }
            if(!cvs.isEmpty())
                EmailServiceUtilities.createContentDocumentLinks(cvs, recordsToLinkFileWith);
            result.success = true;
        }
        catch(Exception ex){
            result.success = true;
            //result.message = ex.getMessage();
            String subjectText = 'Email 2 Service Request Failure';
            String bodyText = ' Exception: ' + ex.getMessage() +
                '\n\n toAddressToKeywordTosObjMapping '+toAddressToKeywordTosObjMapping + 
                '\n\n Stacktrace: ' + ex.getStacktraceString() +
                '\n\n Incoming email: '+email;
            EmailServiceUtilities.sendErrorEmail(subjectText, bodyText);
        }
        return result;
    }
    
}