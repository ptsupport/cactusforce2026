// This test class cover the entire unlocked package including triggers
@IsTest
public class ContractClassTest {
    @testsetup static void setupData() {
        User adminUsr = [SELECT Id,Email FROM User WHERE Profile.Name = 'System Administrator' and IsActive = true LIMIT 1];        
        Branch__c br = new Branch__c(Name='Northeast',Branch_Administrator__c=adminUsr.Id);
        insert br;
        
        Account tstAcct = new Account(Name='ACME',Branch__c=br.Id);
        insert tstAcct;
        
        Opportunity opp = new Opportunity(Name='ACME MACH100 2026',AccountId=tstAcct.Id);
        opp.StageName = 'Value Proposition';
        opp.Amount = 100000;
        opp.CloseDate = Date.today().addMonths(1);
        insert opp;
        
        Contract ct = new Contract(AccountId=tstAcct.Id,Status='Draft');
        ct.ContractTerm = 12;
        ct.StartDate = Date.today().addMonths(1);
        ct.Opportunity__c = opp.Id;
        ct.Sales_Status__c = 'Draft';
        insert ct;

        Contract ct2 = new Contract(AccountId=tstAcct.Id,Status='Draft');
        ct2.ContractTerm = 24;
        ct2.StartDate = Date.today().addMonths(1);
        ct2.Opportunity__c = opp.Id;
        ct2.Sales_Status__c = 'Draft';
        insert ct2;        
    }
    
    @istest static void testDeactivate() {
        Contract ct = [SELECT Id,AccountId,Opportunity__c,Sales_Status__c FROM Contract LIMIT 1];
        Test.startTest();
        ct.Sales_Status__c = 'Activated';
        update ct;
        ct.Sales_Status__c = 'Deactivated';
        update ct;   
        Test.stopTest();
    }

    @istest static void testActivate() {
        Contract ct2 = [SELECT Id,AccountId,Opportunity__c,Sales_Status__c FROM Contract WHERE ContractTerm = 24 LIMIT 1];
        Test.startTest();
        ct2.Sales_Status__c = 'Activated';
        update ct2;   
        Test.stopTest();
    }

    @istest static void testEvent() {
        Contract ct2 = [SELECT Id,AccountId,Opportunity__c,Sales_Status__c FROM Contract WHERE ContractTerm = 24 LIMIT 1];
        Contract ct = [SELECT Id,AccountId,Opportunity__c,Sales_Status__c FROM Contract WHERE ContractTerm = 12 LIMIT 1];
        Test.startTest();
        ContractTriggerHandler.ForceEvent = true;
        ct.Sales_Status__c = 'Activated';
        update ct;
        Test.stopTest();
    }    
}
