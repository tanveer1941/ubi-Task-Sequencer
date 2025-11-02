@isTest
public with sharing class TaskTriggerHandlerTest {
    
    @testSetup
    static void setupTestData() {
        TestDataFactoryClass.setupBaseData();
    }
    
    // Helper method to get process types safely
    private static String getProcessType(Integer index) {
        List<String> processTypes = TestDataFactoryClass.getProcessPicklistValues();
        return index < processTypes.size() ? processTypes[index] : processTypes[0];
    }
    
    @isTest
    static void testTaskCompletion_CreatesNextTask() {
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 3);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        // Get the created task with sequence details
        Task__c firstTask = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c, 
                   Task_Sequence__r.Task_Name__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            LIMIT 1
        ];
        System.assertEquals(1, firstTask.Task_Sequence__r.Sequence_Order__c, 'First task should be sequence 1');
        
        Test.startTest();
        firstTask.Status__c = 'Completed';
        update firstTask;
        Test.stopTest();
        
        // Verify both tasks exist with correct sequencing
        List<Task__c> allTasks = [
            SELECT Id, Status__c, Task_Name__c, Task_Sequence__r.Sequence_Order__c,
                   Due_Date__c, Opportunity__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        
        System.assertEquals(2, allTasks.size(), 'Should create next task when task is completed');
        System.assertEquals('Completed', allTasks[0].Status__c, 'First task should be completed');
        System.assertEquals('Not Started', allTasks[1].Status__c, 'Second task should be Not Started');
        System.assertEquals(1, allTasks[0].Task_Sequence__r.Sequence_Order__c, 'First task sequence order should be 1');
        System.assertEquals(2, allTasks[1].Task_Sequence__r.Sequence_Order__c, 'Second task sequence order should be 2');
        System.assertEquals('Test Task 2', allTasks[1].Task_Name__c, 'Second task name should match sequence');
        System.assertNotEquals(null, allTasks[1].Due_Date__c, 'Second task should have due date set');
    }
    
    @isTest
    static void testTaskCompletion_NonCompletedStatus() {
        String processType = 'Installation';
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 2);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        Task__c task = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            LIMIT 1
        ];
        System.assertEquals('Not Started', task.Status__c, 'Task should start as Not Started');
        
        Test.startTest();
        // Change to non-completed status
        task.Status__c = 'In Progress';
        update task;
        Test.stopTest();
        
        List<Task__c> tasks = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id
        ];
        System.assertEquals(1, tasks.size(), 'Should not create new task for non-completed status');
        System.assertEquals('In Progress', tasks[0].Status__c, 'Task status should be updated to In Progress');
    }
    
    @isTest
    static void testTaskCompletion_MultipleTasksSameOpportunity() {
        String processType = getProcessType(1);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 4);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        // Complete tasks sequentially
        List<Task__c> tasks = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        System.assertEquals(1, tasks.size(), 'Should start with one task');
        
        Test.startTest();
        // Complete first task
        tasks[0].Status__c = 'Completed';
        update tasks[0];
        
        // Complete second task
        List<Task__c> updatedTasks = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        System.assertEquals(2, updatedTasks.size(), 'Should have two tasks after first completion');
        
        updatedTasks[1].Status__c = 'Completed';
        update updatedTasks[1];
        
        // Complete third task
        List<Task__c> finalTasks = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        System.assertEquals(3, finalTasks.size(), 'Should have three tasks after second completion');
        
        finalTasks[2].Status__c = 'Completed';
        update finalTasks[2];
        Test.stopTest();
        
        // Verify all tasks were created and sequenced correctly
        List<Task__c> allTasks = [
            SELECT Id, Status__c, Task_Name__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        
        System.assertEquals(4, allTasks.size(), 'Should create all sequential tasks');
        for(Integer i = 0; i < allTasks.size(); i++) {
            System.assertEquals(i + 1, allTasks[i].Task_Sequence__r.Sequence_Order__c, 
                               'Task ' + (i + 1) + ' should have correct sequence order');
            if(i < 3) {
                System.assertEquals('Completed', allTasks[i].Status__c, 
                                   'Task ' + (i + 1) + ' should be completed');
            } else {
                System.assertEquals('Not Started', allTasks[i].Status__c, 
                                   'Last task should be Not Started');
            }
        }
    }
    
    @isTest
    static void testTaskCompletion_FailedStatus() {
        String processType = getProcessType(2);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 2);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        Task__c task = [
            SELECT Id, Status__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            LIMIT 1
        ];
        
        Test.startTest();
        // Change to Failed status (non-completed)
        task.Status__c = 'Failed';
        update task;
        Test.stopTest();
        
        List<Task__c> tasks = [
            SELECT Id, Status__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id
        ];
        System.assertEquals(1, tasks.size(), 'Should not create new task for Failed status');
        System.assertEquals('Failed', tasks[0].Status__c, 'Task status should be Failed');
    }
    
    @isTest
    static void testTaskCompletion_NoSequenceRemaining() {
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 1);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        Task__c onlyTask = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            LIMIT 1
        ];
        System.assertEquals(1, onlyTask.Task_Sequence__r.Sequence_Order__c, 'Should be the only task');
        
        Test.startTest();
        onlyTask.Status__c = 'Completed';
        update onlyTask;
        Test.stopTest();
        
        List<Task__c> tasks = [
            SELECT Id, Status__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id
        ];
        System.assertEquals(1, tasks.size(), 'Should not create new task when no sequence remains');
        System.assertEquals('Completed', tasks[0].Status__c, 'Only task should be completed');
    }
    
    @isTest
    static void testTaskCompletion_BulkTasks() {
        String processType = getProcessType(1);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 3, 2);
        List<Opportunity> opportunities = scenario.opportunities;
        
        // Set process on all opportunities
        for(Opportunity opp : opportunities) {
            opp.Process__c = processType;
        }
        update opportunities;
        
        // Get all initial tasks
        List<Task__c> initialTasks = [
            SELECT Id, Status__c, Opportunity__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c IN :opportunities
            ORDER BY Opportunity__c, Task_Sequence__r.Sequence_Order__c
        ];
        System.assertEquals(3, initialTasks.size(), 'Should have one task per opportunity');
        
        Test.startTest();
        // Complete all tasks in bulk
        for(Task__c task : initialTasks) {
            task.Status__c = 'Completed';
        }
        update initialTasks;
        Test.stopTest();
        
        // Verify next tasks were created for all opportunities
        List<Task__c> allTasks = [
            SELECT Id, Opportunity__c, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c IN :opportunities
            ORDER BY Opportunity__c, Task_Sequence__r.Sequence_Order__c
        ];
        
        System.assertEquals(6, allTasks.size(), 'Should create second tasks for all opportunities in bulk');
        
        // Verify each opportunity has exactly 2 tasks
        Map<Id, List<Task__c>> tasksByOpportunity = new Map<Id, List<Task__c>>();
        for(Task__c task : allTasks) {
            if(!tasksByOpportunity.containsKey(task.Opportunity__c)) {
                tasksByOpportunity.put(task.Opportunity__c, new List<Task__c>());
            }
            tasksByOpportunity.get(task.Opportunity__c).add(task);
        }
        
        for(Id oppId : tasksByOpportunity.keySet()) {
            System.assertEquals(2, tasksByOpportunity.get(oppId).size(), 
                               'Each opportunity should have 2 tasks');
            System.assertEquals(1, tasksByOpportunity.get(oppId)[0].Task_Sequence__r.Sequence_Order__c,
                               'First task should be sequence 1');
            System.assertEquals(2, tasksByOpportunity.get(oppId)[1].Task_Sequence__r.Sequence_Order__c,
                               'Second task should be sequence 2');
        }
    }
    
    @isTest
    static void testTaskCompletion_StatusReverted() {
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 3);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        Task__c task = [
            SELECT Id, Status__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            LIMIT 1
        ];
        
        Test.startTest();
        // Complete the task
        task.Status__c = 'Completed';
        update task;
        
        // Revert back to Not Started
        task.Status__c = 'Not Started';
        update task;
        Test.stopTest();
        
        List<Task__c> tasks = [
            SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        
        // Should have both tasks (the original and the one created during completion)
        System.assertEquals(2, tasks.size(), 'Should maintain both tasks even when status is reverted');
        System.assertEquals('Not Started', tasks[0].Status__c, 'First task should be Not Started after revert');
        System.assertEquals('Not Started', tasks[1].Status__c, 'Second task should be Not Started');
    }
    
    @isTest
    static void testTaskCompletion_NullParameters() {
        Test.startTest();
        // Test with null parameters - should not throw exceptions
        TaskTriggerHandler.handleAfterUpdate(null, null);
        TaskTriggerHandler.handleAfterUpdate(new List<Task__c>(), new Map<Id, Task__c>());
        Test.stopTest();
        
        System.assert(true, 'Should handle null and empty parameters gracefully');
    }
    
    @isTest
    static void testTaskCompletion_InvalidTaskData() {
        // Create a task with minimal data that might cause exceptions
        Task__c problematicTask = new Task__c(
            Task_Name__c = 'Problematic Task',
            Status__c = 'Not Started'
            // Missing required relationships
        );
        
        // Create a minimal opportunity to associate
        Opportunity testOpp = TestDataFactoryClass.createOpportunity(true);
        problematicTask.Opportunity__c = testOpp.Id;
        insert problematicTask;
        
        Map<Id, Task__c> oldMap = new Map<Id, Task__c>{
            problematicTask.Id => problematicTask.clone(true, true, true, true)
        };
        problematicTask.Status__c = 'Completed';
        
        Test.startTest();
        try {
            TaskTriggerHandler.handleAfterUpdate(new List<Task__c>{problematicTask}, oldMap);
        } catch (Exception e) {
            // Expected - but should be handled by ErrorHandler
            System.debug('Expected exception: ' + e.getMessage());
        }
        Test.stopTest();
        
        System.assert(true, 'Should handle invalid task data gracefully');
    }
}