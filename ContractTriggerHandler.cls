/*
 * This is a Trigger Handler based on Platform Technology's Best Practices Toolkit Trigger Framework
 * Need to save Account's Branch-email-address in Contract and Opportunity, 
 * we well as deactivating non-activated Contracts.
*/
global class ContractTriggerHandler extends pform.TriggerHandler {
    Map<Id,Account> updateAcctsMap = new Map<Id,Account>();
    Set<Id> acctIds = new Set<Id>();
    Set<Id> opptyIds = new Set<Id>();
    List<Contract> newRecords = (List<Contract>)Trigger.new;
    Map<Id, Contract> oldRecords = (Map<Id,Contract>)Trigger.oldMap;
    Map<Id, Contract> newMap = (Map<Id,Contract>)Trigger.newMap;
    Map<Id,Contract> acctConCorrelation = new Map<Id,Contract>();
    Map<Id,Opportunity> conOpptyCorrelation = new Map<Id,Opportunity>();
    Map<Id,Opportunity> opptyMap = new Map<Id,Opportunity>();
    @testvisible public static Boolean ForceEvent = false;
    
    public void updateContractOpptyEmails() {
        System.debug('===ContractTriggerHandler:updateContractEmails: ' + 
                     JSON.serializePretty((Contract)Trigger.new[0]));
        
        for (Contract ct : newRecords) {
            if (ct.AccountId != null) {
            	acctIds.add(ct.AccountId);
                acctConCorrelation.put(ct.AccountId,ct);
            	opptyIds.add(ct.Opportunity__c);
        		System.debug('===ContractTriggerHandlerNew:updateContractEmails:ACCTID: ' + ct.AccountId);
            }
            else {
                pform.ErrorHandler.logError('INFO','ContractTriggerHandler:beforeInsert',
                                            'NULL ACCOUNT ID ON CONTRACT: ' + ct.Id);
            }
        }
        
        Map<Id,Branch__c> brMap = new Map<Id,Branch__c>();
        Map<Id,Contract> conMap = new Map<Id,Contract>();
        Map<Id,User> usrMap = new Map<Id,User>();
        Set<Id> brIds = new Set<Id>();
        Map<Id,Branch__c> usrBranchCorrelation = new Map<Id,Branch__c>();
        Map<Id,Account> branchAcctCorrelation = new Map<Id,Account>();
        
        if (acctIds.size() > 0) {
        	updateAcctsMap = new Map<Id,Account>([SELECT Id,Branch__c FROM Account WHERE Id IN: acctIds FOR UPDATE]); 
            if (updateAcctsMap?.size() > 0) {
                for (Account acct : updateAcctsMap.values()) {
                    if (acct.Branch__c != null) {
                        brIds.add(acct.Branch__c);
                        branchAcctCorrelation.put(acct.Branch__c,acct);
                    }
                }
        		System.debug('===ContractTriggerHandler:updateContractEmails:brIds: ' + JSON.serializePretty(brIds));                
            }

            brMap = new Map<Id,Branch__c>([SELECT Id,Branch_Administrator__c FROM Branch__c WHERE Id IN: brIds]);            
            Set<Id> usrSet = new Set<Id>();
            if (brMap?.size() > 0) {
                for (Branch__c br : brMap.values()) {
                    if (br.Branch_Administrator__c != null) {
                    	usrSet.add(br.Branch_Administrator__c);
                        usrBranchCorrelation.put(br.Branch_Administrator__c,br);
                    }
                }
            }
            
            opptyMap = new Map<Id,Opportunity>([SELECT Id,Branch_Admin_Email__c FROM Opportunity 
                                                WHERE Id IN: opptyIds FOR UPDATE]); //
            if (opptyMap?.size() > 0) {
                for (Contract ct : newRecords) {
                    if (ct.Opportunity__c != null) {
                        conOpptyCorrelation.put(ct.Id,opptyMap.get(ct.Opportunity__c));
                    }
                }
            }
            
            usrMap = new Map<Id,User>([SELECT Id,Email FROM User WHERE Id IN: usrSet AND IsActive = true]);
            if (usrMap.size() > 0) {
                for (User usr : usrMap.values()) {
                    if (!usr.Email.containsIgnoreCase('invalid')) {
                        Branch__c br = usrBranchCorrelation.get(usr.Id);
                        Account acct = branchAcctCorrelation.get(br.Id);
                        Contract con = acctConCorrelation.get(acct.Id);
                        Opportunity opp = opptyMap.get(con.Opportunity__c);
                        opp.Branch_Admin_Email__c = usr.Email;
                        con.Branch_Admin_Email__c = usr.Email;
                        opptyMap.put(opp.Id,opp); // update Oppty Map with email
        				System.debug('===ContractTriggerHandler:updateContractEmails:Email: ' + usr.Email);                        
                    }
                }
            }
        }        
    }
    
    public override void beforeUpdate() {
        try {
            updateContractOpptyEmails();

            for (Contract ct : (List<Contract>)Trigger.new) {
                acctIds.add(ct.AccountId);
            }
            
            // comment out this line to fix the problem:
            //BadApex.doSomethingBad(acctIds); // force limits situation  
            
            updateAcctsMap = new Map<Id,Account>([SELECT Id,Contract_Status__c,Type 
                                                FROM Account WHERE Id IN: acctIds FOR UPDATE]); // FORCE LOCK
            
            // now lets get all the contracts for each Account in case we need to deactivate some
            Map<Id,Contract> contractMap = new Map<Id,Contract>([SELECT Id,Sales_Status__C,AccountId FROM Contract 
                                                                WHERE AccountId IN: updateAcctsMap.keyset() ]); //FOR UPDATE
            Map<Id,Map<Id,Contract>> contractAcctMap = new Map<Id,Map<Id,Contract>>(); // first ID is Account ID
            Map<Id,Contract> ctMap = new Map<Id,Contract>();
            if (contractMap != null && contractMap.size() > 0) {
                for (Contract ct : contractMap.values()) {
                    if (ct.AccountId == null) {
                        continue;
                    }
                    ctMap = contractAcctMap.get(ct.AccountId);
                    if (ctMap == null || ctMap.size() == 0) {
                        ctMap = new Map<Id,Contract>();
                        ctMap.put(ct.Id,ct);
                        contractAcctMap.put(ct.AccountId,ctMap); // save ctMap for this Account
                    }
                    ctMap.put(ct.Id,ct);
                    contractAcctMap.put(ct.AccountId,ctMap); // save ctMap for this Account
                }
            }

            ctMap = new Map<Id,Contract>(); // reset and reuse

            Set<Id> conSet = new Set<Id>();
            for (Contract ct : (List<Contract>)Trigger.new) {
                Contract oldContract = (Contract)Trigger.OldMap.get(ct.Id);
                Account acct = updateAcctsMap.get(ct.AccountId);
                if (ct.Sales_Status__c == 'Activated' && oldContract.Sales_Status__c != 'Activated') {
                    System.debug('===ContractTrigger:Activated');             
                    acct.Contract_Status__c = 'Activated';
                    // make other contracts for this account DEACTIVATED
                    ctMap = contractAcctMap.get(ct.AccountId);
                    if (ctMap != null && ctMap.size() > 1) {
                        for (Contract anotherCt : ctMap.values()) {
                            if (anotherCt.Id != ct.Id) {
                                conSet.add(anotherCt.Id);
                            }
                        }
                    }
                    updateAcctsMap.put(acct.Id,acct);
                } else if (ct.Sales_Status__c == 'Deactivated' && oldContract.Sales_Status__c != 'Deactivated') {
                    System.debug('===ContractTriggerHandler:Deactivated');           
                    acct.Contract_Status__c = 'Deactivated';
                    updateAcctsMap.put(acct.Id,acct);            
                } else if (ct.Sales_Status__c.contains('Pending') && !oldContract.Sales_Status__c.contains('Pending')) {
                    System.debug('===ContractTriggerHandler:Deactivated');           
                    acct.Contract_Status__c = 'Pending';
                    updateAcctsMap.put(acct.Id,acct);            
                }              
            }

            System.debug('===ContractTriggerHandler:UPDATING CON/OPP/ACCT RECORDS');         
            if (conSet.size() > 0) { 
                updateOtherContracts(conSet); // asynch
            }
            if (opptyMap.size() > 0) {
                update opptyMap.values();
            }        
            if (updateAcctsMap.size() > 0) {
                update updateAcctsMap.values();
            }
        } catch (Exception exc) {
            pform.ErrorHandler.logError('DEFAULT','ContractTriggerHandler:beforeUpdate', exc);
        }
    }
    
  
    void updateOtherContracts(Set<Id> conIds) {
        System.debug('===ContractTriggerHandler:updateOtherContracts: ' + JSON.serializePretty(conIds));
        List<Contract> conList = new List<Contract>([SELECT Id,Sales_Status__C,AccountId FROM Contract 
                                                             WHERE Id IN: conIds]);
		// CODE BEFORE USING A PLATFORM EVENT:        
        if (conList != null && conList.size() > 0) {
            for (Contract ct : conList) {
                ct.Sales_Status__C = 'Deactivated';
            }
        }
        
        update conList;  
        
        // un-comment out this line to enable the platform event to create a new transaction allowing the slow Apex-code
        if (ForceEvent) {
			publishContractEvent(conList);
        }
    }

    public static void publishContractEvent(List<Contract> conList) {
		//CODE AFTER USING A PLATFORM EVENT:
        List<Contract_Activation__e> newActivationEvents = new List<Contract_Activation__e>();
        for (Contract ct : conList) {
            Contract_Activation__e cae = new Contract_Activation__e();
            cae.Contract_Id__c = ct.Id;
            cae.Contract_Status__c = 'Deactivated';
            newActivationEvents.add(cae);
        }
        
        System.debug('===ContractTriggerHandler:updateOtherContracts:PUBLISH: ' + JSON.serializePretty(newActivationEvents));        
        EventBus.publish(newActivationEvents);       
    }    
}
