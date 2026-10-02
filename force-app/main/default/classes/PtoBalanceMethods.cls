public without sharing class PtoBalanceMethods {
    
    //helper class for pay periods
    public class hlcPayPeriod {
        public Date startDate;
        public Date endDate;
        public Decimal ptoTaken;
        public Decimal ptoRequested;
        
        //constructor
        public hlcPayPeriod() {
            ptoTaken = 0;
            ptoRequested = 0;
        }
    }
    //static variable to prevent recursion
    public static boolean calculatePtoBalance = true;
    
    /////////////////////////////////////////////////////
    //Given a PTO Balance record, populate the starting balance on all subsequent balance records
    /////////////////////////////////////////////////////
    public static void ptoBalanceAdjusted(List<PTO_Balance__c> lstNewBalances, Map<Id, PTO_Balance__c> mapOldBalances) {
        List<PTO_Balance__c> balancesToUpdate = new List<PTO_Balance__c>();
        for (PTO_Balance__c oBalance : lstNewBalances) {
            if (oBalance.Mgmt_Adjustment__c != mapOldBalances.get(oBalance.Id).Mgmt_Adjustment__c
	               	|| oBalance.Hours_Taken__c != mapOldBalances.get(oBalance.Id).Hours_Taken__c
					|| oBalance.Hours_Requested__c != mapOldBalances.get(oBalance.Id).Hours_Requested__c) {
                balancesToUpdate.add(oBalance);
            }
        }
        if(!balancesToUpdate.isEmpty()) updateFollowingBalances(balancesToUpdate);
    }

    /////////////////////////////////////////////////////
    //Given a PTO Balance record, populate the starting balance on all subsequent balance records
    /////////////////////////////////////////////////////
    @InvocableMethod(label='Update Following Balances' description='Given a PTO Balance record, populate the starting balance on all subsequent balance records')
    public static void updateFollowingBalances(List<PTO_Balance__c> oBalances){
        List<PTO_Balance__c> ptoBalancesToUpdate = new List<PTO_Balance__c>();
        
        //retrieve all subsequent PTO_Balances from the passed in PTO Balances
        //we find subsequent balances by matching the Employee__c field
        List<Id> employeeIds = new List<Id>();
        Date earliestStartDate = oBalances[0].Start_Date__c;
        for (PTO_Balance__c balance: oBalances){
            employeeIds.add(balance.Employee__c);
            if (earliestStartDate > balance.Start_Date__c){
                earliestStartDate = balance.Start_Date__c;
            }
        }
        List<PTO_Balance__c> subsequentBalances = [Select Id
                                                        , Start_Date__c
                                                        , End_Date__c
                                                        , Record_ID__c 
                                                        , Employee__c
                                                        , Starting_Balance__c
                                                        , Mgmt_Adjustment__c
                                                        , Hours_Taken__c
                                                        , Hours_Requested__c
                                                        , Hours_Taken_Requested__c //kdj
                                                        , Accrued_Hours__c
                                                        , PTO_Accrual_Setup__c
                                                        , PTO_Accrual_Setup__r.Carryover_Allowed__c
                                                        , PTO_Accrual_Setup__r.Accrual_Rate__c
                                                    From PTO_Balance__c 
                                                    Where Employee__c IN :employeeIds
                                                        And Start_Date__c > :earliestStartDate
                                                    Order By Start_Date__c];

        //create a map from Employee__c field to PTO_Balance__c records
        Map<Id,List<PTO_Balance__c>> employeeIdToPTOBalances = new Map<Id,List<PTO_Balance__c>>();
        for (PTO_Balance__c balance : subsequentBalances){
            if (employeeIdToPTOBalances.containsKey(balance.Employee__c)){
                employeeIdToPTOBalances.get(balance.Employee__c).add(balance);
            } else {
                employeeIdToPTOBalances.put(balance.Employee__c,new List<PTO_Balance__c>{balance});
            }
        }

        for(PTO_Balance__c oBalance : oBalances){
            system.debug('Inside updateFollowingBalances.  Processing ' + oBalance);
            //if the pto balance doesn't have any subsequent pto balances, we skip it
            if (!employeeIdToPTOBalances.containsKey(oBalance.Employee__c)) break;
            //calculate ending balance for the given record and use it as the starting balance for the next record
            Decimal nextStartingBalance = (nullToZero(oBalance.Starting_Balance__c) + nullToZero(oBalance.Accrued_Hours__c) + nullToZero(oBalance.Mgmt_Adjustment__c)) - oBalance.Hours_Taken_Requested__c; //kdj
            system.debug('Initial nextStartingBalance oBalance: ' + nextStartingBalance);
            
            for (PTO_Balance__c oNextBalance : employeeIdToPTOBalances.get(oBalance.Employee__c)) {
                //if the pto balance doesn't start after the current pto balance, we skip it.
                if (oNextBalance.Start_Date__c < oBalance.Start_Date__c) break;
                //if the period is the first of the year, ensure the starting balance does not exceed the max allowed carryover
                if (oNextBalance.Start_Date__c.month() == 1 
                        && oNextBalance.Start_Date__c.day() == 1 
                        && nextStartingBalance > oNextBalance.PTO_Accrual_Setup__r.Carryover_Allowed__c) {
                    nextStartingBalance = oNextBalance.PTO_Accrual_Setup__r.Carryover_Allowed__c;
                }
                oNextBalance.Starting_Balance__c = nextStartingBalance;
                system.debug('Initial nextStartingBalance oNextBalance: ' + nextStartingBalance);
                ptoBalancesToUpdate.add(oNextBalance);

                //set the starting balance for the next balance record
                nextStartingBalance = (nullToZero(oNextBalance.Starting_Balance__c) + nullToZero(oNextBalance.Accrued_Hours__c) + nullToZero(oNextBalance.Mgmt_Adjustment__c)) - oNextBalance.Hours_Taken_Requested__c; //kdj
                system.debug('Next Balance: ' + oNextBalance
                             + '\nnextStartingBalance: ' + nextStartingBalance);                           
            }
        }
        if (!ptoBalancesToUpdate.isEmpty()) {
            for (PTO_Balance__c oBal : ptoBalancesToUpdate) {
                system.debug(oBal);
            }
            update ptoBalancesToUpdate;
        }
    }

    /////////////////////////////////////////////////////
    //Given a PTO Balance record, populate the starting balance on all subsequent balance records
    /////////////////////////////////////////////////////
    // public static void updateFollowingBalances(PTO_Balance__c oBalance) {
    //     //calculate ending balance for the given record and use it as the starting balance for the next record
    //     Decimal nextStartingBalance = nullToZero(oBalance.Starting_Balance__c) + nullToZero(oBalance.Accrued_Hours__c) + nullToZero(oBalance.Mgmt_Adjustment__c);
    //     if (oBalance.End_Date__c < date.today()) {
    //         nextStartingBalance = nextStartingBalance - nullToZero(oBalance.Hours_Taken__c);
    //     } else {
    //         nextStartingBalance = nextStartingBalance - nullToZero(oBalance.Hours_Requested__c);
    //     }
        
    //     List<PTO_Balance__c> lstNextBalances = new List<PTO_Balance__c>();
    //     for (PTO_Balance__c oNextBalance : [Select Id
	// 											, Start_Date__c
	// 											, End_Date__c
	// 											, Record_ID__c 
	// 											, Employee__c
    //                                         	, Starting_Balance__c
	// 											, Mgmt_Adjustment__c
    //                                         	, Hours_Taken__c
    //                                         	, Hours_Requested__c
    //                                         	, Accrued_Hours__c
	// 											, PTO_Accrual_Setup__c
    //                                         	, PTO_Accrual_Setup__r.Carryover_Allowed__c
    //                                         	, PTO_Accrual_Setup__r.Accrual_Rate__c
	// 										From PTO_Balance__c 
    //                                         Where Employee__c = :oBalance.Employee__c
    //                                             And Start_Date__c > :oBalance.End_Date__c
    //                                         Order By Start_Date__c]) {
	// 		//if the period is the first of the year, ensure the starting balance does not exceed the max allowed carryover
	// 		if (oNextBalance.Start_Date__c.month() == 1 
	// 				&& oNextBalance.Start_Date__c.day() == 1 
	// 				&& nextStartingBalance > oNextBalance.PTO_Accrual_Setup__r.Carryover_Allowed__c) {
	// 			nextStartingBalance = oNextBalance.PTO_Accrual_Setup__r.Carryover_Allowed__c;
	// 		}
	// 		oNextBalance.Starting_Balance__c = nextStartingBalance;
	// 		lstNextBalances.add(oNextBalance);

	// 		//set the starting balance for the next balance record
	// 		nextStartingBalance = nullToZero(oNextBalance.Starting_Balance__c) + nullToZero(oNextBalance.Accrued_Hours__c) + nullToZero(oNextBalance.Mgmt_Adjustment__c);
    //     	if (oNextBalance.End_Date__c < date.today()) {
	//             nextStartingBalance = nextStartingBalance - nullToZero(oNextBalance.Hours_Taken__c);
	//         } else {
	//             nextStartingBalance = nextStartingBalance - nullToZero(oNextBalance.Hours_Requested__c);
	//         }                                 
    //     }
    //     update lstNextBalances;
    // }
    
    /////////////////////////////////////////////////////
    //Utility to return 0 if the provided value is null
    /////////////////////////////////////////////////////
    public static decimal nullToZero(Decimal val) {
        if (val == null) {
            val = 0.0;
        }
        return val;
    }
        
    /////////////////////////////////////////////////////
    //Generate or update PTO Balance records for the given PTO Accrual Setup record
    // Create one record per pay period in the range of the record
    /////////////////////////////////////////////////////
    public static void generatePTOBalances(PTO_Accrual_Setup__c oAccrualSetup) {
        //delete existing PTO Balance records if they fall outside the timeframe in the setup record
        PtoBalanceMethods.deleteOutOfRangeBalanceRecords(oAccrualSetup);
        
        //retrieve employee details
        Set<Id> setEmployeeIds = new Set<Id>();
        setEmployeeIds.add(oAccrualSetup.Employee__c);
        Map<Id, Contact> mapEmployees = PtoBalanceMethods.fetchEmployees(setEmployeeIds);
        Contact currEmployee;
        currEmployee = mapEmployees.get(oAccrualSetup.Employee__c);
        
		//get the existing PTO Balance records for the employee in the accrual timeframe
		Map<String, PTO_Balance__c> mapExistingBalances = new Map<String, PTO_Balance__c>();
        for (PTO_Balance__c oExistingBalance : [Select Id
                                                    , Start_Date__c
                                                    , End_Date__c
                                                    , Record_ID__c 
                                                    , Employee__c
                                                	, Mgmt_Adjustment__c
                                                	, PTO_Accrual_Setup__c
                                            From PTO_Balance__c 
                                            Where Employee__c = :oAccrualSetup.Employee__c
                                                And Start_Date__c >= :oAccrualSetup.Accrual_Start_Date__c 
                                                And End_Date__c <= :oAccrualSetup.Accrual_End_Date__c
                                            Order By Start_Date__c]) {
            mapExistingBalances.put(oExistingBalance.Record_ID__c, oExistingBalance);
        }
        
        //If the setup record has a starting balance specfied, use it as the starting balance for the first period.  Otherwise get the ending balance from 
        // the most recent PTO Balance record prior to the given time frame and use it as the starting balance for this timeframe
        Decimal startingBalance = 0.0;
        if (oAccrualSetup.Starting_PTO_Balance__c != null) {
            startingBalance = oAccrualSetup.Starting_PTO_Balance__c;
        } else {
            for (PTO_Balance__c oBalance : [Select Id
                                                    , Start_Date__c
                                                    , End_Date__c
                                                    , Ending_Balance__c 
                                                    , Employee__c
                                            From PTO_Balance__c 
                                            Where PTO_Accrual_Setup__c != null
                                                And Employee__c = :oAccrualSetup.Employee__c
                                                And End_Date__c < :oAccrualSetup.Accrual_Start_Date__c 
                                            Order By End_Date__c DESC
											LIMIT 1]) {
                startingBalance = oBalance.Ending_Balance__c;
			}
        }
        List<PtoBalanceMethods.hlcPayPeriod> lstPayPeriods = PtoBalanceMethods.buildPayPeriods(oAccrualSetup.Accrual_Start_Date__c, oAccrualSetup.Accrual_End_Date__c, currEmployee);

        //for each pay period, build the PTO Balance records
        List<PTO_Balance__c> lstPtoBalances = new List<PTO_Balance__c>();
        for (PtoBalanceMethods.hlcPayPeriod oPayPeriod : lstPayPeriods) {
            Datetime dttStartDate = Datetime.newInstance(oPayPeriod.startDate.year(), oPayPeriod.startDate.month(), oPayPeriod.startDate.day());
            String balanceName = currEmployee.FirstName + ' ' 
                + currEmployee.LastName + ' - ' 
                + dttStartDate.format('YYYY-MM-dd');
            string recordId = oAccrualSetup.Employee__c + '_' + dttStartDate.format('YYYYMMdd');
            Decimal mgmtAdj = 0.0;
            if (mapExistingBalances.containsKey(recordId) && mapExistingBalances.get(recordId).Mgmt_Adjustment__c != null) {
                mgmtAdj = mapExistingBalances.get(recordId).Mgmt_Adjustment__c;                
            }
            
            //adjust starting balance for first of the year
            if (oPayPeriod.startDate.month() == 1 
					&& oPayPeriod.startDate.day() == 1 
                	&& startingBalance > nullToZero(oAccrualSetup.Carryover_Allowed__c)) {
                startingBalance = oAccrualSetup.Carryover_Allowed__c;
            }
            PTO_Balance__c oNewBalance = new PTO_Balance__c(Name = balanceName
                                                            , OwnerId = currEmployee.pse__Salesforce_User__c
                                                            , Employee__c = currEmployee.Id
                                                            , Record_ID__c = recordId
                                                            , Start_Date__c = oPayPeriod.startDate
                                                            , End_Date__c = oPayPeriod.endDate
                                                            , Starting_Balance__c = startingBalance
                                                            , Accrued_Hours__c = oAccrualSetup.Accrual_Rate__c
                                                            , Hours_Requested__c = oPayPeriod.ptoRequested
                                                            , Hours_Taken__c = oPayPeriod.ptoTaken
                                                            , Mgmt_Adjustment__c = mgmtAdj
                                                            , PTO_Accrual_Setup__c = oAccrualSetup.Id);
            lstPtoBalances.add(oNewBalance);
            startingBalance = startingBalance + oAccrualSetup.Accrual_Rate__c + mgmtAdj;
            if (oPayPeriod.endDate < date.today()) {
                startingBalance = startingBalance - oPayPeriod.ptoTaken;
            } else {
                startingBalance = startingBalance - oPayPeriod.ptoRequested;
            }
        }
		upsert lstPtoBalances Record_ID__c;
        system.debug('Calling updateFollowingBalances from generatePTOBalances');
        PtoBalanceMethods.updateFollowingBalances(new List<PTO_Balance__c>{lstPtoBalances.get(lstPtoBalances.size()-1)});
        
    }   

    /////////////////////////////////////////////////////
    //Delete existing PTO Balance records from the provided setup record if they fall outside
    // the timeframe in the setup record.
    /////////////////////////////////////////////////////
    public static void deleteOutOfRangeBalanceRecords(PTO_Accrual_Setup__c oAccrualSetup) {
        List<PTO_Balance__c> lstBalances = new List<PTO_Balance__c>();
        for (PTO_Balance__c oBalance : [Select Id
                                        		, Start_Date__c
                                        		, End_Date__c
                                        		, PTO_Accrual_Setup__c 
                                        		, Employee__c
										From PTO_Balance__c 
                                        Where PTO_Accrual_Setup__c = :oAccrualSetup.Id
											And (End_Date__c < :oAccrualSetup.Accrual_Start_Date__c 
												Or Start_Date__c > :oAccrualSetup.Accrual_End_Date__c)
                                        Order By End_Date__c DESC]) {
            lstBalances.add(new PTO_Balance__c(Id=oBalance.Id
												, PTO_Accrual_Setup__c = null));
        }
        delete lstBalances;
    }

    /////////////////////////////////////////////////////
    //Retrieve employee contacts with the given ids
    /////////////////////////////////////////////////////
    public static Map<Id, Contact> fetchEmployees(Set<Id> setEmployeeIds) {
        Map<Id, Contact> retVal = new Map<Id, Contact>([Select Id
                                   							, FirstName
                                                        	, LastName
                                                        	, ContactStatus__c
                                                        	, PTO_Balance_Calculated_Using__c
                                                        	, pse__Salesforce_User__c
                                                        	, RecordType.Name
                                                        From Contact 
                                                        Where Id in :setEmployeeIds]);        
        return retVal;
    }
    
    /////////////////////////////////////////////////////
    //Given a date range, construct the pay periods between them
    /////////////////////////////////////////////////////
    public static List<PtoBalanceMethods.hlcPayPeriod> buildPayPeriods(Date startDate, Date endDate, Contact oEmployee) {        
        List<PtoBalanceMethods.hlcPayPeriod> retVal = new List<PtoBalanceMethods.hlcPayPeriod>();
        Integer startDay = 1;
        if (startDate.day() > 15) {
            startDay = 16;
        }
        
        Map<Date, Decimal> mapRequestedByPeriod = PtoBalanceMethods.fetchPTORequested(startDate, endDate, oEmployee.Id, null);
        Map<Date, Decimal> mapTakenByPeriod = PtoBalanceMethods.fetchPTOTaken(startDate, endDate, oEmployee.Id, null);

        Date payPeriodStart = Date.newInstance(startDate.year(), startDate.month(), startDay);
        while (payPeriodStart < endDate) {
            PtoBalanceMethods.hlcPayPeriod oPayPeriod = new PtoBalanceMethods.hlcPayPeriod();
            Date payPeriodEnd;
            oPayPeriod.startDate = payPeriodStart;
            if (payPeriodStart.day() == 1) {
                //end date is 15th of month
                payPeriodEnd = Date.newInstance(payPeriodStart.year(), payPeriodStart.month(), 15);
            } else {
                //end date is last day of month
                payPeriodEnd = Date.newInstance(payPeriodStart.year(), payPeriodStart.month(), 1).addMonths(1).addDays(-1);
            }
            oPayPeriod.endDate = payPeriodEnd;
            if (mapRequestedByPeriod.containsKey(payPeriodStart)) {
	            oPayPeriod.ptoRequested = mapRequestedByPeriod.get(payPeriodStart);
                if (oEmployee.PTO_Balance_Calculated_Using__c == 'PTO Request' && payPeriodEnd < date.today())  {
                    oPayPeriod.ptoTaken = mapRequestedByPeriod.get(payPeriodStart);
                }
            }
            if (mapTakenByPeriod.containsKey(payPeriodStart) && oEmployee.PTO_Balance_Calculated_Using__c == 'Timecard') {
	            oPayPeriod.ptoTaken = mapTakenByPeriod.get(payPeriodStart);
            }
            retVal.add(oPayPeriod);
            payPeriodStart = payPeriodEnd.addDays(1);
        }
        return retVal;
    }
    
    /////////////////////////////////////////////////////
    //Get PTO taken by the given employee during the given time frame
    // Since a timecard can span multiple pay periods, we need to inspect each day
    /////////////////////////////////////////////////////
    public static Map<Date, Decimal> fetchPTOTaken(Date startDate, Date endDate, Id employeeId, Id ignoreTimecardId) {
        Map<Date, Decimal> mapPTOTakenByPeriod = new Map<Date, Decimal>();
        for (pse__Timecard_Header__c oTimecard : [Select Id
                                                        , Name
                                                        , pse__Start_Date__c
                                                        , pse__End_Date__c
                                                        , pse__Sunday_Hours__c
                                                        , pse__Monday_Hours__c
                                                        , pse__Tuesday_Hours__c
                                                        , pse__Wednesday_Hours__c
                                                        , pse__Thursday_Hours__c
                                                        , pse__Friday_Hours__c
                                                        , pse__Saturday_Hours__c
                                                        , pse__Status__c
                                                        , pse__Submitted__c
                                                        , pse__Project__c
                                                        , pse__Project__r.Name
                                                        , pse__Resource__c
                                                        , pse__Resource__r.FirstName
                                                        , pse__Resource__r.LastName
													From pse__Timecard_Header__c
													Where (pse__Project__r.Name = 'PTO'
														And pse__Resource__c = :employeeId
														And pse__Status__c = 'Approved'
														And Id != :ignoreTimecardId)
														And ((pse__Start_Date__c >= :startDate And pse__Start_Date__c <= :endDate)
															Or (pse__End_Date__c >= :startDate And pse__End_Date__c <= :endDate))
													Order By pse__Start_Date__c]) {
			mapPTOTakenByPeriod = PtoBalanceMethods.processPTOTimecard(startDate, endDate, oTimecard, mapPTOTakenByPeriod);
		}        
        return mapPTOTakenByPeriod;
    }
    
    //////////////////////////////////////////////////////////////
    //given a date, return the first day of the pay period in which it falls
    //////////////////////////////////////////////////////////////
    public static Date getPeriodStartDate(Date dtValue) {
		Date periodStartDate = Date.newInstance(dtValue.year(), dtValue.month(), 1);
		if (dtValue.day() > 15) {
			periodStartDate = Date.newInstance(dtValue.year(), dtValue.month(), 16);
		}
		return periodStartDate;        
    }
    
    /////////////////////////////////////////////////////
    //Get PTO taken by the given employee during the given time frame
    /////////////////////////////////////////////////////
    public static Map<Date, Decimal> fetchPTORequested(Date startDate, Date endDate, Id employeeId, Id ignoreAssignmentId) {
        Map<Date, Decimal> mapPeriodPTORequested = new Map<Date, Decimal>();

        for (pse__Assignment__c oAssignment : [Select Id
                                                    , Name
                                                    , pse__Start_Date__c
                                                    , pse__End_Date__c
                                                    , pse__Scheduled_Hours__c
                                                    , pse__Status__c
                                                    , pse__Project__c
                                                    , pse__Project__r.Name
                                                    , pse__Resource__c
                                                    , pse__Resource__r.FirstName
                                                    , pse__Resource__r.LastName
                                                    , pse__Schedule__c
                                                    , pse__Schedule__r.pse__Start_Date__c
                                                    , pse__Schedule__r.pse__End_Date__c
                                                    , pse__Schedule__r.pse__Scheduled_Days__c
                                                    , pse__Schedule__r.pse__Scheduled_Hours__c
                                                    , pse__Schedule__r.pse__Sunday_Hours__c
                                                    , pse__Schedule__r.pse__Monday_Hours__c
                                                    , pse__Schedule__r.pse__Tuesday_Hours__c
                                                    , pse__Schedule__r.pse__Wednesday_Hours__c
                                                    , pse__Schedule__r.pse__Thursday_Hours__c
                                                    , pse__Schedule__r.pse__Friday_Hours__c
                                                    , pse__Schedule__r.pse__Saturday_Hours__c
                                                From pse__Assignment__c
                                                Where pse__Project__r.Name = 'PTO'
                                                    And pse__Resource__c = :employeeId
                                                    And Id != :ignoreAssignmentId
                                                    And pse__Status__c = 'Scheduled'
                                                    And ((pse__Start_Date__c >= :startDate And pse__Start_Date__c <= :endDate)
                                                        Or (pse__End_Date__c >= :startDate And pse__End_Date__c <= :endDate))
                                                Order By pse__Start_Date__c]) {
			mapPeriodPTORequested = PtoBalanceMethods.processPTORequested(oAssignment, oAssignment.pse__Schedule__r, mapPeriodPTORequested);
		}        
        return mapPeriodPTORequested;
    }
    
    /////////////////////////////////////////////////////
    //Get PTO Balance records for the given employee during the given time frame
    /////////////////////////////////////////////////////
    public static Map<Date, PTO_Balance__c> fetchPTOBalances(Date startDate, Date endDate, Id employeeId) {
        Map<Date, PTO_Balance__c> retVal = new Map<Date, PTO_Balance__c>();
        for (PTO_Balance__c oBalance : [Select Id
                                            , Start_Date__c
                                            , End_Date__c
                                            , Record_ID__c 
                                            , Employee__c
                                            , Starting_Balance__c
                                            , Mgmt_Adjustment__c
                                            , Hours_Taken__c
                                            , Hours_Requested__c
											, Hours_Taken_Requested__c
                                        	, Accrued_Hours__c
                                            , PTO_Accrual_Setup__c
                                            , PTO_Accrual_Setup__r.Carryover_Allowed__c
                                            , PTO_Accrual_Setup__r.Accrual_Rate__c
										From PTO_Balance__c 
                                        Where Employee__c = :employeeId
                                            And ((Start_Date__c <= :startDate And End_Date__c >= :startDate)
												Or (Start_Date__c <= :endDate And End_Date__c >= :endDate))
                                        Order By Start_Date__c]) {
			retVal.put(oBalance.Start_Date__c, oBalance);
		}
        
        return retVal;
    }
    
    /////////////////////////////////////////////////////
    //Given a timecard, update the PTO Balance record(s) falling in the same timeframe 
    /////////////////////////////////////////////////////
    public static void updatePTOTaken(List<pse__Timecard_Header__c> lstTimecards) {
        
        Set<Id> setProjectIds = new Set<Id>();
        for (pse__Timecard_Header__c oTimecard_GetProject : lstTimecards) {
            setProjectIds.add(oTimecard_GetProject.pse__Project__c);
        }        
        Map<Id, pse__Proj__c> mapProjects = new Map<Id, pse__Proj__c>([Select Id, Name From pse__Proj__c Where Id in :setProjectIds]);
        
        //only process approved timecards associated to the PTO project
        for (pse__Timecard_Header__c oTimecard : lstTimecards) {
            if (oTimecard.pse__Status__c == 'Approved' 
					&& mapProjects.containsKey(oTimecard.pse__Project__c) 
                	&& mapProjects.get(oTimecard.pse__Project__c).Name == 'PTO') {
                //find the PTO Balance records to be updated
                Map<Date, PTO_Balance__c> mapBalances = PtoBalanceMethods.fetchPTOBalances(oTimecard.pse__Start_Date__c, oTimecard.pse__End_Date__c, oTimecard.pse__Resource__c);
				//no need to continue if no PTO Balance records found
				if (mapBalances.size() == 0) {
					break;
				}
                //determine the period start and end dates based on the PTO Balance records retrieved
                Date startDate;
                Date endDate;
                for (PTO_Balance__c oBalance : mapBalances.values()) {
                    if (startDate == null || startDate > oBalance.Start_Date__c) {
                        startDate = oBalance.Start_Date__c;
                    }
                    if (endDate == null || endDate < oBalance.End_Date__c) {
                        endDate = oBalance.End_Date__c;
                    }
                }
                //get time taken on the other timecards in this given timeframe and then add the time taken on the provided timecard
                Map<Date, Decimal> mapPeriodPTOTaken = PtoBalanceMethods.fetchPTOTaken(startDate, endDate, oTimecard.pse__Resource__c, oTimecard.Id);
                mapPeriodPTOTaken = PtoBalanceMethods.processPTOTimecard(startDate, endDate, oTimecard, mapPeriodPTOTaken);
                
                //now that we PTO taken for each period, update the PTO Balance records
                Integer recsProcessed = 0;
                Decimal nextStartingBalance = 0.0;
                PTO_Balance__c oLastBalanceRec = null;
                for (Date periodStartDate : mapPeriodPTOTaken.keySet()) {
                    if (mapBalances.containsKey(periodStartDate)) {
                        PTO_Balance__c oUpdatedBalance = mapBalances.get(periodStartDate);
                        oUpdatedBalance.Hours_Taken__c = mapPeriodPTOTaken.get(periodStartDate);
                        if (recsProcessed > 0) {
                            oUpdatedBalance.Starting_Balance__c = nextStartingBalance;
                        }
						nextStartingBalance = (nullToZero(oUpdatedBalance.Starting_Balance__c) + nullToZero(oUpdatedBalance.Accrued_Hours__c) + nullToZero(oUpdatedBalance.Mgmt_Adjustment__c)) - oUpdatedBalance.Hours_Taken_Requested__c; //kdj
                        //kdj nextStartingBalance = nullToZero(oUpdatedBalance.Starting_Balance__c) + nullToZero(oUpdatedBalance.Accrued_Hours__c) + nullToZero(oUpdatedBalance.Mgmt_Adjustment__c);
                        /* kdj
                        if (oUpdatedBalance.End_Date__c > date.today()) {
                            nextStartingBalance = nextStartingBalance - nullToZero(oUpdatedBalance.Hours_Requested__c);
                        } else {
                            nextStartingBalance = nextStartingBalance - nullToZero(oUpdatedBalance.Hours_Taken__c);
                        }
                        */
                        mapBalances.put(periodStartDate, oUpdatedBalance);
                        oLastBalanceRec = oUpdatedBalance;
                        recsProcessed++;
                    }
                }
                
                update mapBalances.values();
				if (oLastBalanceRec != null) {
                    system.debug('Calling updateFollowingBalances from updatePTOTaken');
                	PtoBalanceMethods.updateFollowingBalances(new List<PTO_Balance__c>{oLastBalanceRec});
                }
            }
        }        
    }

    /////////////////////////////////////////////////////
    //Given a time frame, timecard and a map of PTO taken by pay period, update the map so it includes PTO taken on the given timecard
    /////////////////////////////////////////////////////
	public static Map<Date, Decimal> processPTOTimecard(Date startDate, Date endDate, pse__Timecard_Header__c oTimecard, Map<Date, Decimal> mapPeriodPTOTaken) {
        Decimal takenHours = 0;
        
        Date periodStartDate;
        Date dtSunday = oTimecard.pse__Start_Date__c;
        Date dtMonday = oTimecard.pse__Start_Date__c.addDays(1);
        Date dtTuesday = oTimecard.pse__Start_Date__c.addDays(2);
        Date dtWednesday = oTimecard.pse__Start_Date__c.addDays(3);
        Date dtThursday = oTimecard.pse__Start_Date__c.addDays(4);
        Date dtFriday = oTimecard.pse__Start_Date__c.addDays(5);
        Date dtSaturday = oTimecard.pse__End_Date__c;
        
        if (oTimecard.pse__Sunday_Hours__c > 0 && dtSunday >= startDate && dtSunday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtSunday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Sunday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        if (oTimecard.pse__Monday_Hours__c > 0 && dtMonday >= startDate && dtMonday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtMonday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Monday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        if (oTimecard.pse__Tuesday_Hours__c > 0 && dtTuesday >= startDate && dtTuesday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtTuesday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Tuesday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        if (oTimecard.pse__Wednesday_Hours__c > 0 && dtWednesday >= startDate && dtWednesday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtWednesday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Wednesday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        if (oTimecard.pse__Thursday_Hours__c > 0 && dtThursday >= startDate && dtThursday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtThursday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Thursday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        if (oTimecard.pse__Friday_Hours__c > 0 && dtFriday >= startDate && dtFriday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtFriday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Friday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        if (oTimecard.pse__Saturday_Hours__c > 0 && dtSaturday >= startDate && dtSaturday <= endDate) {
        	takenHours = 0;
            periodStartDate = PtoBalanceMethods.getPeriodStartDate(dtSaturday);
            if (mapPeriodPTOTaken.containsKey(periodStartDate)) {
                takenHours = mapPeriodPTOTaken.get(periodStartDate);
            }
            takenHours += oTimecard.pse__Saturday_Hours__c;
	        mapPeriodPTOTaken.put(periodStartDate, takenHours);
        }
        
		return mapPeriodPTOTaken;
	}
        
    /////////////////////////////////////////////////////
    //Given requested PTO assignments, update the PTO Balance record(s) falling in the same timeframes 
    /////////////////////////////////////////////////////
    public static void updatePTORequested(List<pse__Assignment__c> lstAssignments) {
        
        Set<Id> setProjectIds = new Set<Id>();
        Set<Id> setScheduleIds = new Set<Id>();
        for (pse__Assignment__c oAssignment_GetProject : lstAssignments) {
            setProjectIds.add(oAssignment_GetProject.pse__Project__c);
            setScheduleIds.add(oAssignment_GetProject.pse__Schedule__c);
        }        
        Map<Id, pse__Proj__c> mapProjects = new Map<Id, pse__Proj__c>([Select Id, Name From pse__Proj__c Where Name = 'PTO' And Id in :setProjectIds]);
        Map<Id, pse__Schedule__c> mapSchedules = new Map<Id, pse__Schedule__c>([Select Id
																					, pse__Scheduled_Days__c
                                                                                	, pse__Scheduled_Hours__c
                                                                                	, pse__Start_Date__c
                                                                                	, pse__End_Date__c
                                                                                	, pse__Sunday_Hours__c
                                                                                	, pse__Monday_Hours__c
                                                                                	, pse__Tuesday_Hours__c
                                                                                	, pse__Wednesday_Hours__c
                                                                                	, pse__Thursday_Hours__c
                                                                                	, pse__Friday_Hours__c
                                                                                	, pse__Saturday_Hours__c 
																				From pse__Schedule__c 
                                                                                Where Id in :setScheduleIds]);
        
        //only process scheduled assignments associated to the PTO project
        for (pse__Assignment__c oAssignment : lstAssignments) {
            if (oAssignment.pse__Start_Date__c != null
                	&& oAssignment.pse__Status__c == 'Scheduled' 
					&& mapProjects.containsKey(oAssignment.pse__Project__c)) {
                //find the PTO Balance records to be updated
                Map<Date, PTO_Balance__c> mapBalances = PtoBalanceMethods.fetchPTOBalances(oAssignment.pse__Start_Date__c, oAssignment.pse__End_Date__c, oAssignment.pse__Resource__c);
				system.debug('Inside updatePTORequested.  Fetch PTO Balances for start date: ' + oAssignment.pse__Start_Date__c + ', end date: ' + oAssignment.pse__End_Date__c + '\nmapBalances: ' + mapBalances);
                
                //determine the period start and end dates based on the PTO Balance records retrieved
                Date startDate = null;
                Date endDate = null;
                for (PTO_Balance__c oBalance : mapBalances.values()) {
                    system.debug('startDate: ' + startDate + ' oBalance.Start_Date__c: ' + oBalance.Start_Date__c + 'endDate: ' + endDate + ' oBalance.End_Date__c: ' + oBalance.End_Date__c);
                    if (startDate == null || startDate > oBalance.Start_Date__c) {
                        startDate = oBalance.Start_Date__c;
                    }
                    if (endDate == null || endDate < oBalance.End_Date__c) {
                        endDate = oBalance.End_Date__c;
                    }
                }
                //get time requested on the other assignments in this given timeframe and then add the time requested on the provided assignment
                Map<Date, Decimal> mapRequestedByPeriod = PtoBalanceMethods.fetchPTORequested(startDate, endDate, oAssignment.pse__Resource__c, oAssignment.Id);
				mapRequestedByPeriod = PtoBalanceMethods.processPTORequested(oAssignment, mapSchedules.get(oAssignment.pse__Schedule__c), mapRequestedByPeriod);
                
                //now that we PTO requested for each period, update the PTO Balance records
                Integer recsProcessed = 0;
                Decimal nextStartingBalance = 0.0;
                PTO_Balance__c oLastBalanceRec = null;
                for (Date periodStartDate : mapRequestedByPeriod.keySet()) {
                    if (mapBalances.containsKey(periodStartDate)) {
                        PTO_Balance__c oUpdatedBalance = mapBalances.get(periodStartDate);
                        oUpdatedBalance.Hours_Requested__c = mapRequestedByPeriod.get(periodStartDate);
                        if (recsProcessed > 0) {
                            oUpdatedBalance.Starting_Balance__c = nextStartingBalance;
                        }
                        nextStartingBalance = nullToZero(oUpdatedBalance.Starting_Balance__c) + nullToZero(oUpdatedBalance.Accrued_Hours__c) - oUpdatedBalance.Hours_Taken_Requested__c + nullToZero(oUpdatedBalance.Mgmt_Adjustment__c); //kdj
                        //kdj nextStartingBalance = nullToZero(oUpdatedBalance.Starting_Balance__c) + nullToZero(oUpdatedBalance.Accrued_Hours__c) - nullToZero(oUpdatedBalance.Hours_Taken__c) + nullToZero(oUpdatedBalance.Mgmt_Adjustment__c);
                        mapBalances.put(periodStartDate, oUpdatedBalance);
                        oLastBalanceRec = oUpdatedBalance;
                    }
                }
                
                update mapBalances.values();
				if (oLastBalanceRec != null) {
                    //requery last balance record so all formula fields are updated
                    oLastBalanceRec = [Select Id
                                            , Start_Date__c
                                            , End_Date__c
                                            , Record_ID__c 
                                            , Employee__c
                                            , Starting_Balance__c
                                            , Mgmt_Adjustment__c
                                            , Hours_Taken__c
                                            , Hours_Requested__c
											, Hours_Taken_Requested__c
                                        	, Accrued_Hours__c
                                            , PTO_Accrual_Setup__c
                                            , PTO_Accrual_Setup__r.Carryover_Allowed__c
                                            , PTO_Accrual_Setup__r.Accrual_Rate__c
										From PTO_Balance__c 
                        				Where Id = :oLastBalanceRec.Id
                                        LIMIT 1];
                    system.debug('Calling updateFollowingBalances from updatePTORequested.  oLastBalanceRec: ' + oLastBalanceRec);                    
                	PtoBalanceMethods.updateFollowingBalances(new List<PTO_Balance__c>{oLastBalanceRec});
                }
            }
        }        
    }
    
    /////////////////////////////////////////////////////
    //Given an assignment, a schedule and a map of PTO requested by pay period, update the map so it includes PTO requested on the given schedule
    /////////////////////////////////////////////////////
    public static Map<Date, Decimal> processPTORequested(pse__Assignment__c oAssignment, pse__Schedule__c oSchedule, Map<Date, Decimal> mapPeriodPTORequested) {
        DateTime dttProcessDate = DateTime.newInstance(oAssignment.pse__Start_Date__c.year(), oAssignment.pse__Start_Date__c.month(), oAssignment.pse__Start_Date__c.day());
        Date periodStartDate = getPeriodStartDate(oAssignment.pse__Start_Date__c);
		Decimal requestedHours = 0;
		system.debug('Inside processPTORequested.  oAssignment: ' + oAssignment);
        while (dttProcessDate.date() <= oAssignment.pse__End_Date__c) {
            periodStartDate = getPeriodStartDate(dttProcessDate.date());
            requestedHours = 0;
            if (mapPeriodPTORequested.containsKey(periodStartDate)) {
                requestedHours = mapPeriodPTORequested.get(periodStartDate);
            }
            switch on dttProcessDate.format('EEEE') {
                when 'Sunday' {
                    requestedHours += oSchedule.pse__Sunday_Hours__c;
                }
                when 'Monday' {
                    requestedHours += oSchedule.pse__Monday_Hours__c;
                }
                when 'Tuesday' {
                    requestedHours += oSchedule.pse__Tuesday_Hours__c;
                }
                when 'Wednesday' {
                    requestedHours += oSchedule.pse__Wednesday_Hours__c;
                }
                when 'Thursday' {
                    requestedHours += oSchedule.pse__Thursday_Hours__c;
                }
                when 'Friday' {
                    requestedHours += oSchedule.pse__Friday_Hours__c;
                }
                when 'Saturday' {
                    requestedHours += oSchedule.pse__Saturday_Hours__c;
                }
            }
			mapPeriodPTORequested.put(periodStartDate, requestedHours);
            system.debug('mapPeriodPTORequested: ' + mapPeriodPTORequested);
            dttProcessDate = dttProcessDate.addDays(1);
        }

        return mapPeriodPTORequested;
    }
    
    /////////////////////////////////////////////////////
    //Ensure setup records do not overlap
    //  Scenario #1: New date range completely includes an existing range
    //  Scenario #2: New start date falls into an existing range
    //  Scenario #3: New end date falls into an existing range
    /////////////////////////////////////////////////////
    public static void checkForOverlappingAccruals(PTO_Accrual_Setup__c oAccrualSetup) {
        Date newStartDate = oAccrualSetup.Accrual_Start_Date__c;
        Date newEndDate = oAccrualSetup.Accrual_End_Date__c;
		String errRecords = '';        
        for (PTO_Accrual_Setup__c oSetupCheck : [Select Id, Name, Accrual_Start_Date__c, Accrual_End_Date__c 
												From PTO_Accrual_Setup__c 
												Where Employee__c = :oAccrualSetup.Employee__c
                                                 	And Id != :oAccrualSetup.Id
                                            		And ((Accrual_Start_Date__c >= :newStartDate And Accrual_End_Date__c <= :newEndDate)
													Or (Accrual_Start_Date__c <= :newStartDate And Accrual_End_Date__c >= :newStartDate)
                                                    Or (Accrual_Start_Date__c <= :newEndDate And Accrual_End_Date__c >= :newEndDate))]) {
			String formattedStartDate = Datetime.newInstance(oSetupCheck.Accrual_Start_Date__c.year(), oSetupCheck.Accrual_Start_Date__c.month(), oSetupCheck.Accrual_Start_Date__c.day()).format('MM/dd/yyyy');
			String formattedEndDate = Datetime.newInstance(oSetupCheck.Accrual_End_Date__c.year(), oSetupCheck.Accrual_End_Date__c.month(), oSetupCheck.Accrual_End_Date__c.day()).format('MM/dd/yyyy');
			errRecords += oSetupCheck.Name + ' (' + formattedStartDate + ' - ' + formattedEndDate + '), ';
		}

		if (errRecords != '') {
            errRecords = errRecords.Left(errRecords.length()-2);
			oAccrualSetup.addError('Overlapping dates not allowed.  The following Accrual Setup records have overlapping dates: ' + errRecords);
        }
        
    }

    /////////////////////////////////////////////////////
    //Delete PTO Balance Records associated to the given setup records
    /////////////////////////////////////////////////////
    public static void deletePtoBalance(Map<id, PTO_Accrual_Setup__c> mapDeleteAccrual) {
        List<PTO_Balance__c> deletePto = New List<PTO_Balance__c>();
        for (PTO_Balance__c delPto : [select id from PTO_Balance__c where PTO_Accrual_Setup__c in :mapDeleteAccrual.keyset()]){
			deletePto.add(delPto);
        }
        delete deletePto;
    }
}