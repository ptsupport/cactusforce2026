// This class exists simply to cause enough overhead to hit a limit for demonstration purposes
// Always avoid SOQL in a FOR loop unless it is an extremely rare and limited loop scenario
public class BadApex {

    public static void doSomethingBad(Set<Id> conIds) {
        Set<Id> acctIds = new Set<Id>();
		Map<Id,Contract> conMap = new Map<Id,Contract>([SELECT Id,AccountId  FROM Contract where Id IN: conIds]);
        for (Contract con : conMap.values()) {
            acctIds.add(con.AccountId);
        }
        
        for (Integer i=0; i < 95; i++) {
			List<Account> acctList = new List<Account>([SELECT Id,Description FROM Account where Id IN: acctIds FOR UPDATE]);    
            for (Account acct : acctList) {
                acct.Description = String.valueOf(i);
            }
    
            update acctList; // should hit SOQL limit 
        }
    }    
}
