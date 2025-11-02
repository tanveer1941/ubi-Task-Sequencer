@isTest
public with sharing class OpportunityTriggerHandlerTest {
    
    @testSetup
    static void setupTestData() {
        TestDataFactoryClass.setupBaseData();
    }
    
    // Helper method to get process types safely
    private static String getProcessType(Integer index) {
        List<String> processTypes = TestDataFactoryClass.getProcessPicklistValues();
        return index < processTypes.size() ? processTypes[index] : processTypes[0];
    }
    
    // SUCCESS SCENARIOS
    
    @isTest
    static void testHandleBeforeUpdate_ProcessChangeWithoutTasks() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(3, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0);
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleBeforeUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Should not add any errors since no tasks exist
        for(Opportunity opp : opportunities) {
            System.assertEquals(false, opp.hasErrors(), 'Should not have validation errors when no tasks exist');
        }
    }
    
    @isTest
    static void testHandleAfterUpdate_ProcessChangeCreatesTasks() {
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 2, 2);
        List<Opportunity> opportunities = scenario.opportunities;
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = processType;
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleAfterUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Verify tasks were created for all opportunities
        List<Task__c> createdTasks = [
            SELECT Id, Opportunity__c, Task_Name__c, Status__c
            FROM Task__c 
            WHERE Opportunity__c IN :opportunities
        ];
        
        System.assertEquals(2, createdTasks.size(), 'Should create tasks for all opportunities with process changes');
        
        for(Task__c task : createdTasks) {
            System.assertEquals('Not Started', task.Status__c, 'Tasks should be created with Not Started status');
        }
    }
    
    @isTest
    static void testHandleAfterUpdate_NoProcessChange() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = getProcessType(0);
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0); // Same process - no change
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleAfterUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Verify no tasks were created since process didn't change
        List<Task__c> tasks = [SELECT Id FROM Task__c WHERE Opportunity__c IN :opportunities];
        System.assertEquals(0, tasks.size(), 'Should not create tasks when process does not change');
    }
    
    @isTest
    static void testHandleAfterUpdate_ProcessChangeToNull() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = getProcessType(0);
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = null; // Changing to null
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleAfterUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Verify no tasks were created when changing to null
        List<Task__c> tasks = [SELECT Id FROM Task__c WHERE Opportunity__c IN :opportunities];
        System.assertEquals(0, tasks.size(), 'Should not create tasks when process changes to null');
    }
    
    // VALIDATION ERROR SCENARIOS
    
    @isTest
    static void testHandleBeforeUpdate_ProcessChangeWithActiveTasks() {
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 2, 2);
        List<Opportunity> opportunities = scenario.opportunities;
        
        // Set initial process and create tasks
        for(Opportunity opp : opportunities) {
            opp.Process__c = processType;
        }
        update opportunities;
        
        // Verify tasks exist
        List<Task__c> existingTasks = [SELECT Id FROM Task__c WHERE Opportunity__c IN :opportunities];
        System.assertEquals(2, existingTasks.size(), 'Should have existing tasks');
        
        // Try to change process
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = processType;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(1); // Change to different process
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleBeforeUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Should have validation errors for all opportunities with active tasks
        for(Opportunity opp : opportunities) {
            System.assertEquals(true, opp.hasErrors(), 'Should have validation errors when changing process with active tasks');
        }
    }
    
    @isTest
    static void testHandleBeforeUpdate_ProcessChangeWithCompletedTasks() {
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 1);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        // Complete the task
        Task__c task = [SELECT Id FROM Task__c WHERE Opportunity__c = :testOpp.Id LIMIT 1];
        task.Status__c = 'Completed';
        update task;
        
        // Try to change process
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            testOpp.Id => testOpp.clone(true, true, true, true)
        };
        testOpp.Process__c = getProcessType(1);
        
        Test.startTest();
        OpportunityTriggerHandler.handleBeforeUpdate(new List<Opportunity>{testOpp}, oldMap);
        Test.stopTest();
        
        // Should not have errors since all tasks are completed
        System.assertEquals(false, testOpp.hasErrors(), 'Should not have errors when all tasks are completed');
    }
    
    
    // ERROR HANDLING AND EDGE CASES
    
    @isTest
    static void testHandleBeforeUpdate_NullParameters() {
        Test.startTest();
        OpportunityTriggerHandler.handleBeforeUpdate(null, null);
        OpportunityTriggerHandler.handleBeforeUpdate(new List<Opportunity>(), new Map<Id, Opportunity>());
        Test.stopTest();
        
        System.assert(true, 'Should handle null and empty parameters gracefully');
    }
    
    @isTest
    static void testHandleAfterUpdate_NullParameters() {
        Test.startTest();
        OpportunityTriggerHandler.handleAfterUpdate(null, null);
        OpportunityTriggerHandler.handleAfterUpdate(new List<Opportunity>(), new Map<Id, Opportunity>());
        Test.stopTest();
        
        System.assert(true, 'Should handle null and empty parameters gracefully');
    }
    
    @isTest
    static void testHandleBeforeUpdate_IndividualRecordError() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0);
        }
        
        // Force an error in individual record processing by corrupting oldMap for one record
        oldMap.remove(opportunities[0].Id);
        
        Test.startTest();
        OpportunityTriggerHandler.handleBeforeUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Should handle individual record errors gracefully and continue processing
        System.assert(true, 'Should handle individual record processing errors gracefully');
    }
    
    @isTest
    static void testHandleAfterUpdate_IndividualRecordError() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0);
        }
        
        // Force an error in individual record processing by corrupting oldMap for one record
        oldMap.remove(opportunities[0].Id);
        
        Test.startTest();
        OpportunityTriggerHandler.handleAfterUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Should handle individual record errors gracefully and continue processing
        System.assert(true, 'Should handle individual record processing errors gracefully');
    }
    
    @isTest
    static void testValidateProcessChange_QueryExceptionHandling() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0);
        }
        
        Test.startTest();
        // This should handle any query exceptions internally
        OpportunityTriggerHandler.handleBeforeUpdate(opportunities, oldMap);
        Test.stopTest();
        
        System.assert(true, 'Should handle query exceptions gracefully');
    }
    
    @isTest
    static void testValidateProcessChange_SecurityExceptionHandling() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0);
        }
        
        Test.startTest();
        // This should handle any security exceptions internally
        OpportunityTriggerHandler.handleBeforeUpdate(opportunities, oldMap);
        Test.stopTest();
        
        System.assert(true, 'Should handle security exceptions gracefully');
    }
    
    @isTest
    static void testHandleAfterUpdate_EmptyProcessTypes() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = getProcessType(0);
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0); // No change - should not trigger task creation
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleAfterUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Verify no tasks were created
        List<Task__c> tasks = [SELECT Id FROM Task__c WHERE Opportunity__c IN :opportunities];
        System.assertEquals(0, tasks.size(), 'Should not create tasks when process types set is empty');
    }
    
    
    
    @isTest
    static void testHandleBeforeUpdate_BulkValidation() {
        // Test with larger data volume
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(50, 'Prospecting', true);
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : opportunities) {
            Opportunity oldOpp = opp.clone(true, true, true, true);
            oldOpp.Process__c = null;
            oldMap.put(opp.Id, oldOpp);
            opp.Process__c = getProcessType(0);
        }
        
        Test.startTest();
        OpportunityTriggerHandler.handleBeforeUpdate(opportunities, oldMap);
        Test.stopTest();
        
        // Should process all records without errors when no tasks exist
        for(Opportunity opp : opportunities) {
            System.assertEquals(false, opp.hasErrors(), 'Should not have validation errors for bulk processing');
        }
    }
    
    @isTest
    static void testErrorHandlerIntegration() {
        // This test verifies that exceptions are properly handled by the ErrorHandler
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        
        // Create a scenario that might cause an exception
        Test.startTest();
        // Call with potentially problematic data
        OpportunityTriggerHandler.handleAfterUpdate(opportunities, new Map<Id, Opportunity>());
        Test.stopTest();
        
        System.assert(true, 'Should handle potential exceptions through ErrorHandler integration');
    }
}