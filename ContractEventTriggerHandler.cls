// A Trigger Handler based on Platform Technology's Best Practices Toolkit Trigger Framework
// This Trigger Handler simply invokes the BadApex to show it is in a separate transaction.
global class ContractEventTriggerHandler extends pform.TriggerHandler {

    public override void afterInsert() {
        
    	List<Contract_Activation__e> newActivationEvents = (List<Contract_Activation__e>)Trigger.new;
        Set<Id> conIds = new Set<Id>();
        
        for (Contract_Activation__e cae : newActivationEvents) {
            conIds.add(cae.Contract_Id__c);
        }
        
        // uncomment-out this line to fix the problem from the Trigger/TriggerHandler
        if (ContractTriggerHandler.ForceEvent) {
        	BadApex.doSomethingBad(conIds);
        }
	}  
}
