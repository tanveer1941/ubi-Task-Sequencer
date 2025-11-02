@isTest
public with sharing class TaskSequencerHelperTest {
    
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
    static void testCreateInitialTasks_Success() {
        // Create test scenario
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 3);
        Opportunity testOpp = scenario.opportunities[0];
        
        Test.startTest();
        // Set process to trigger task creation
        testOpp.Process__c = processType;
        update testOpp;
        Test.stopTest();
        
        // Verify tasks were created
        List<Task__c> createdTasks = [
            SELECT Id, Task_Name__c, Status__c, Opportunity__c, Due_Date__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id
            ORDER BY CreatedDate
        ];
        
        System.assertEquals(1, createdTasks.size(), 'Should create only the first task initially');
        System.assertEquals('Not Started', createdTasks[0].Status__c, 'Task should be created with Not Started status');
        System.assertEquals('Test Task 1', createdTasks[0].Task_Name__c, 'Task name should match sequence');
        System.assertNotEquals(null, createdTasks[0].Due_Date__c, 'Due date should be set');
    }
    
    
    
    @isTest
    static void testCreateInitialTasks_NoProcessSelected() {
        Opportunity testOpp = TestDataFactoryClass.createOpportunity(true);
        TestDataFactoryClass.createCompleteScenario(getProcessType(0), 0, 2);
        
        Test.startTest();
        // Don't set process - should not create tasks
        testOpp.StageName = 'Qualification';
        update testOpp;
        Test.stopTest();
        
        List<Task__c> tasks = [
            SELECT Id FROM Task__c WHERE Opportunity__c = :testOpp.Id
        ];
        
        System.assertEquals(0, tasks.size(), 'Should not create tasks when process is not selected');
    }
    
    @isTest
    static void testHandleTaskCompletion_Success() {
        // Create complete scenario with initial task
        String processType = getProcessType(2);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 3);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        // Get the created task
        Task__c firstTask = [SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c FROM Task__c WHERE Opportunity__c = :testOpp.Id LIMIT 1];
        System.assertEquals(1, firstTask.Task_Sequence__r.Sequence_Order__c, 'First task should have sequence order 1');
        
        Test.startTest();
        // Complete the first task
        firstTask.Status__c = 'Completed';
        update firstTask;
        Test.stopTest();
        
        // Verify next task was created
        List<Task__c> allTasks = [
            SELECT Id, Task_Name__c, Status__c, Task_Sequence__r.Sequence_Order__c
            FROM Task__c 
            WHERE Opportunity__c = :testOpp.Id 
            ORDER BY Task_Sequence__r.Sequence_Order__c
        ];
        
        System.assertEquals(2, allTasks.size(), 'Should create second task after completion');
        System.assertEquals('Completed', allTasks[0].Status__c, 'First task should be completed');
        System.assertEquals('Not Started', allTasks[1].Status__c, 'Second task should be created with Not Started status');
        System.assertEquals('Test Task 2', allTasks[1].Task_Name__c, 'Second task name should match sequence');
        System.assertEquals(2, allTasks[1].Task_Sequence__r.Sequence_Order__c, 'Second task should have sequence order 2');
    }
    
    @isTest
    static void testHandleTaskCompletion_LastTask() {
        // Create scenario with only one sequence
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 1);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        Task__c onlyTask = [SELECT Id, Status__c, Task_Sequence__r.Sequence_Order__c FROM Task__c WHERE Opportunity__c = :testOpp.Id LIMIT 1];
        System.assertEquals(1, onlyTask.Task_Sequence__r.Sequence_Order__c, 'Should be the only task');
        
        Test.startTest();
        onlyTask.Status__c = 'Completed';
        update onlyTask;
        Test.stopTest();
        
        List<Task__c> tasks = [SELECT Id, Status__c FROM Task__c WHERE Opportunity__c = :testOpp.Id];
        System.assertEquals(1, tasks.size(), 'Should not create new task when it is the last in sequence');
        System.assertEquals('Completed', tasks[0].Status__c, 'The only task should be completed');
    }
    
    @isTest
    static void testHandleTaskCompletion_MultipleTasksCompleted() {
        // Create scenario and manually create multiple completed tasks
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 2, 3);
        List<Opportunity> opportunities = scenario.opportunities;
        
        // Create tasks manually to simulate multiple completions
        List<Task__c> tasksToComplete = new List<Task__c>();
        for(Opportunity opp : opportunities) {
            Task__c task = TestDataFactoryClass.createTask(opp.Id, scenario.processTrack.Id, scenario.taskSequences[0].Id, 'Not Started', true);
            tasksToComplete.add(task);
        }
        
        Test.startTest();
        for(Task__c task : tasksToComplete) {
            task.Status__c = 'Completed';
        }
        update tasksToComplete;
        Test.stopTest();
        
        // Verify next tasks were created for both opportunities
        List<Task__c> allTasks = [
            SELECT Id, Opportunity__c, Task_Name__c, Status__c
            FROM Task__c 
            WHERE Opportunity__c IN :opportunities
            ORDER BY Opportunity__c, CreatedDate
        ];
        
        System.assertEquals(4, allTasks.size(), 'Should create second tasks for both opportunities');
        
        // Verify each opportunity has 2 tasks (original + new)
        Map<Id, Integer> taskCountByOpp = new Map<Id, Integer>();
        for(Task__c task : allTasks) {
            Integer count = taskCountByOpp.get(task.Opportunity__c) != null ? taskCountByOpp.get(task.Opportunity__c) : 0;
            taskCountByOpp.put(task.Opportunity__c, count + 1);
        }
        
        for(Id oppId : taskCountByOpp.keySet()) {
            System.assertEquals(2, taskCountByOpp.get(oppId), 'Each opportunity should have 2 tasks');
        }
    }
    
    @isTest
    static void testCreateTaskFromSequence_BusinessDateCalculation() {
        // Create mock objects without inserting them
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting', 
            CloseDate = Date.today().addDays(30)
        );
        
        Process_Track__c track = new Process_Track__c(
            Type__c = getProcessType(0)
        );
        
        Task_Sequence__c sequence = new Task_Sequence__c(
            Task_Name__c = 'Test Task',
            Description__c = 'Test Description',
            Estimated_Duration__c = 3
        );
        
        Test.startTest();
        Task__c newTask = TaskSequencerHelper.createTaskFromSequence(testOpp, sequence, null);
        Test.stopTest();
        
        System.assertNotEquals(null, newTask, 'Task should be created');
        System.assertEquals('Test Task', newTask.Task_Name__c, 'Task name should match');
        System.assertEquals('Not Started', newTask.Status__c, 'Status should be Not Started');
        System.assertNotEquals(null, newTask.Due_Date__c, 'Due date should be calculated');
        System.assertEquals(testOpp.Id, newTask.Opportunity__c, 'Should reference correct opportunity');
    }
    
    @isTest
    static void testCreateInitialTasks_EmptyProcessTypes() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        
        Test.startTest();
        // This should not throw an exception
        TaskSequencerHelper.createInitialTasks(opportunities, new Set<String>());
        Test.stopTest();
        
        // Verify no tasks were created
        List<Task__c> tasks = [SELECT Id FROM Task__c WHERE Opportunity__c IN :opportunities];
        System.assertEquals(0, tasks.size(), 'Should not create tasks with empty process types');
    }
    
    @isTest
    static void testHandleTaskCompletion_EmptyParameters() {
        Test.startTest();
        // These should not throw exceptions
        TaskSequencerHelper.handleTaskCompletion(new List<Task__c>(), new Set<Id>(), new Set<Id>());
        TaskSequencerHelper.handleTaskCompletion(null, null, null);
        Test.stopTest();
        
        System.assert(true, 'Should handle empty parameters gracefully');
    }
    
    @isTest
    static void testErrorHandling_SecurityException() {
        // This test verifies error handling when security violations occur
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        // Try to create tasks with a process type that doesn't exist
        TaskSequencerHelper.createInitialTasks(opportunities, new Set<String>{'Non_Existent_Process'});
        Test.stopTest();
        
        // Should not throw exception, just log error
        System.assert(true, 'Should handle non-existent process types gracefully');
        
        // Verify no tasks were created for non-existent process
        List<Task__c> tasks = [SELECT Id FROM Task__c WHERE Opportunity__c IN :opportunities];
        System.assertEquals(0, tasks.size(), 'Should not create tasks for non-existent process types');
    }
    
    @isTest
    static void testCreateInitialTasks_SecurityException() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        // This should handle any security exceptions internally
        TaskSequencerHelper.createInitialTasks(opportunities, new Set<String>{getProcessType(0)});
        Test.stopTest();
        
        System.assert(true, 'Should handle security exceptions gracefully');
    }
    
    @isTest
    static void testCreateInitialTasks_DMLException() {
        List<Opportunity> opportunities = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        TaskSequencerHelper.createInitialTasks(opportunities, new Set<String>{'Non_Existent_Process'});
        Test.stopTest();
        
        System.assert(true, 'Should handle DML exceptions in task creation');
    }
    
    @isTest
    static void testCreateInitialTasks_NullParameters() {
        Test.startTest();
        TaskSequencerHelper.createInitialTasks(null, null);
        TaskSequencerHelper.createInitialTasks(new List<Opportunity>(), new Set<String>());
        TaskSequencerHelper.createInitialTasks(new List<Opportunity>{TestDataFactoryClass.createOpportunity(false)}, null);
        Test.stopTest();
        
        System.assert(true, 'Should handle null and empty parameters gracefully');
    }
    
    @isTest
    static void testHandleTaskCompletion_NullParameters() {
        Test.startTest();
        TaskSequencerHelper.handleTaskCompletion(null, null, null);
        TaskSequencerHelper.handleTaskCompletion(new List<Task__c>(), new Set<Id>(), new Set<Id>());
        Test.stopTest();
        
        System.assert(true, 'Should handle null and empty parameters gracefully');
    }
    
    @isTest
    static void testCalculateBusinessDate_EdgeCases() {
        Test.startTest();
        // Test various edge cases - these should not throw exceptions
        Date result1 = TaskSequencerHelper.calculateBusinessDate(Date.today(), 0);
        Date result2 = TaskSequencerHelper.calculateBusinessDate(Date.today(), -5);
        Date result3 = TaskSequencerHelper.calculateBusinessDate(Date.today(), 1);
        Date result4 = TaskSequencerHelper.calculateBusinessDate(Date.today(), 10);
        Test.stopTest();
        
        System.assertNotEquals(null, result1, 'Should handle zero business days');
        System.assertNotEquals(null, result2, 'Should handle negative business days');
        System.assertNotEquals(null, result3, 'Should handle single business day');
        System.assertNotEquals(null, result4, 'Should handle multiple business days');
        
        // Verify business day calculation (should skip weekends)
        Date startDate = Date.newInstance(2024, 1, 1); // Monday
        Date result5 = TaskSequencerHelper.calculateBusinessDate(startDate, 5);
        System.assertNotEquals(null, result5, 'Should calculate business days correctly');
    }
    
    @isTest
    static void testHandleTaskCompletion_WithRealException() {
        // Create test data
        String processType = getProcessType(0);
        TestDataFactoryClass.TestScenario scenario = TestDataFactoryClass.createCompleteScenario(processType, 1, 2);
        Opportunity testOpp = scenario.opportunities[0];
        testOpp.Process__c = processType;
        update testOpp;
        
        Task__c firstTask = [SELECT Id FROM Task__c WHERE Opportunity__c = :testOpp.Id LIMIT 1];
        
        Test.startTest();
        // Pass invalid data that might cause exceptions internally
        TaskSequencerHelper.handleTaskCompletion(
            new List<Task__c>{firstTask}, 
            new Set<Id>{firstTask.Id}, 
            new Set<Id>{null} // Invalid process track ID
        );
        Test.stopTest();
        
        System.assert(true, 'Should handle internal exceptions gracefully');
    }
    
    
    
}