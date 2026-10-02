global class PtoBalanceSchedulable implements Schedulable {

    global void execute(SchedulableContext sc) {
        List<PTO_Balance__c> allPtoBalances = [Select Id
                , Start_Date__c
                , End_Date__c
                , Record_ID__c 
                , Employee__c
                , Starting_Balance__c
                , Mgmt_Adjustment__c
                , Hours_Taken__c
                , Hours_Requested__c
                , Accrued_Hours__c
                , PTO_Accrual_Setup__c
                , PTO_Accrual_Setup__r.Carryover_Allowed__c
                , PTO_Accrual_Setup__r.Accrual_Rate__c
            From PTO_Balance__c 
            Order By Start_Date__c
        ];

        //create a map from Employee__c field to PTO_Balance__c records
        Map<Id,List<PTO_Balance__c>> employeeIdToPTOBalances = new Map<Id,List<PTO_Balance__c>>();
        for (PTO_Balance__c balance: allPtoBalances){
            if (employeeIdToPTOBalances.containsKey(balance.Employee__c)){
                employeeIdToPTOBalances.get(balance.Employee__c).add(balance);
            } else {
                employeeIdToPTOBalances.put(balance.Employee__c,new List<PTO_Balance__c>{balance});
            }
        }

        for(Id employeeId: employeeIdToPTOBalances.keySet()){
            Boolean firstBalance = true;
            Decimal nextStartingBalance;
            for(PTO_Balance__c balance: employeeIdToPTOBalances.get(employeeId)){
                if (firstBalance){
                    firstBalance = false;
                } else {
                    //if the period is the first of the year, ensure the starting balance does not exceed the max allowed carryover
                    if (balance.Start_Date__c.month() == 1 
                            && balance.Start_Date__c.day() == 1 
                            && nextStartingBalance > balance.PTO_Accrual_Setup__r.Carryover_Allowed__c) {
                        nextStartingBalance = balance.PTO_Accrual_Setup__r.Carryover_Allowed__c;
                    }
                    balance.Starting_Balance__c = nextStartingBalance;
                }
                //calculate ending balance for the given record and use it as the starting balance for the next record
                nextStartingBalance = PtoBalanceMethods.nullToZero(balance.Starting_Balance__c) + PtoBalanceMethods.nullToZero(balance.Accrued_Hours__c) + PtoBalanceMethods.nullToZero(balance.Mgmt_Adjustment__c);
                if (balance.End_Date__c < date.today()) {
                    nextStartingBalance = nextStartingBalance - PtoBalanceMethods.nullToZero(balance.Hours_Taken__c);
                } else {
                    nextStartingBalance = nextStartingBalance - PtoBalanceMethods.nullToZero(balance.Hours_Requested__c);
                }    
            }
        }
        update allPtoBalances;
    }

}