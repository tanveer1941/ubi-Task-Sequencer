public with sharing class TaskSequencerHelper {
    
    public static void createInitialTasks(List<Opportunity> opportunities, Set<String> processTypes) {
        try {
            // null check
            if (opportunities == null || opportunities.isEmpty() || processTypes == null || processTypes.isEmpty()) {
                return;
            }
            
            List<Task__c> tasksToCreate = new List<Task__c>();
            
            // Query task sequences with error handling
            List<Task_Sequence__c> taskSequences;
            try {
                taskSequences = [
                    SELECT Id, Name, Process_Track__r.Type__c, Sequence_Order__c, 
                           Task_Name__c, Description__c, Estimated_Duration__c
                    FROM Task_Sequence__c 
                    WHERE Process_Track__r.Type__c IN :processTypes
                    WITH SECURITY_ENFORCED
                    ORDER BY Process_Track__r.Type__c, Sequence_Order__c
                    
                ];
            } catch (Exception queryEx) {
                ErrorHandler.handleError(
                    'TaskSequencerHelper', 
                    'createInitialTasks', 
                    queryEx, 
                    opportunities,
                    ErrorHandler.ErrorSeverity.HIGH,
                    new Map<String, Object>{
                        'context' => 'Querying Task Sequences',
                        'processTypes' => processTypes
                    }
                );
                return;
            }
            
            // Strip inaccessible fields from query results
            List<Task_Sequence__c> safeTaskSequences;
            try {
                SObjectAccessDecision taskSequenceDecision = Security.stripInaccessible(AccessType.READABLE, taskSequences);
                safeTaskSequences = (List<Task_Sequence__c>)taskSequenceDecision.getRecords();
            } catch (Exception securityEx) {
                System.debug('Security strip failed, using original records: ' + securityEx.getMessage());
                safeTaskSequences = taskSequences;
            }
            
            Map<String, List<Task_Sequence__c>> processToSequences = new Map<String, List<Task_Sequence__c>>();
            for(Task_Sequence__c seq : safeTaskSequences) {
                try {
                    if(seq.Process_Track__r != null && seq.Process_Track__r.Type__c != null) {
                        if(!processToSequences.containsKey(seq.Process_Track__r.Type__c)) {
                            processToSequences.put(seq.Process_Track__r.Type__c, new List<Task_Sequence__c>());
                        }
                        processToSequences.get(seq.Process_Track__r.Type__c).add(seq);
                    }
                } catch (Exception processingEx) {
                    System.debug('Error processing task sequence ' + seq.Id + ': ' + processingEx.getMessage());
                }
            }
            
            // Query process tracks with error handling
            List<Process_Track__c> processTracks;
            try {
                processTracks = [
                    SELECT Id, Type__c 
                    FROM Process_Track__c 
                    WHERE Type__c IN :processTypes
                    WITH SECURITY_ENFORCED
                ];
            } catch (Exception queryEx) {
                ErrorHandler.handleError(
                    'TaskSequencerHelper', 
                    'createInitialTasks', 
                    queryEx, 
                    opportunities,
                    ErrorHandler.ErrorSeverity.HIGH,
                    new Map<String, Object>{
                        'context' => 'Querying Process Tracks',
                        'processTypes' => processTypes
                    }
                );
                return;
            }
            
            // Strip inaccessible fields from query results
            List<Process_Track__c> safeProcessTracks;
            try {
                SObjectAccessDecision processTrackDecision = Security.stripInaccessible(AccessType.READABLE, processTracks);
                safeProcessTracks = (List<Process_Track__c>)processTrackDecision.getRecords();
            } catch (Exception securityEx) {
                System.debug('Security strip failed, using original records: ' + securityEx.getMessage());
                safeProcessTracks = processTracks;
            }
            
            Map<String, Id> processTypeToTrackId = new Map<String, Id>();
            for(Process_Track__c track : safeProcessTracks) {
                try {
                    if(track.Type__c != null) {
                        processTypeToTrackId.put(track.Type__c, track.Id);
                    }
                } catch (Exception processingEx) {
                    System.debug('Error processing process track ' + track.Id + ': ' + processingEx.getMessage());
                }
            }
            
            // Create initial tasks
            for(Opportunity opp : opportunities) {
                try {
                    if(opp.Process__c != null && processToSequences.containsKey(opp.Process__c)) {
                        List<Task_Sequence__c> sequences = processToSequences.get(opp.Process__c);
                        
                        // Create only the first task initially
                        if(!sequences.isEmpty() && sequences[0] != null) {
                            Task_Sequence__c firstSequence = sequences[0];
                            Task__c newTask = createTaskFromSequence(opp, firstSequence, processTypeToTrackId.get(opp.Process__c));
                            if(newTask != null) {
                                tasksToCreate.add(newTask);
                            }
                        }
                    }
                } catch (Exception taskCreationEx) {
                    System.debug('Error creating task for Opportunity ' + opp.Id + ': ' + taskCreationEx.getMessage());
                    // Continue with other opportunities
                }
            }
            
            if(!tasksToCreate.isEmpty()) {
                try {
                    // Strip inaccessible fields before insert
                    SObjectAccessDecision taskInsertDecision = Security.stripInaccessible(AccessType.CREATABLE, tasksToCreate);
                    List<Task__c> safeTasksToCreate = (List<Task__c>)taskInsertDecision.getRecords();
                    
                    // Use database.insert for partial success handling
                    Database.SaveResult[] insertResults = Database.insert(safeTasksToCreate, false);
                    
                    // Check for individual failures
                    List<Task__c> failedTasks = new List<Task__c>();
                    for(Integer i = 0; i < insertResults.size(); i++) {
                        if(!insertResults[i].isSuccess()) {
                            failedTasks.add(safeTasksToCreate[i]);
                            System.debug('Failed to insert task: ' + insertResults[i].getErrors());
                        }
                    }
                    
                    if(!failedTasks.isEmpty()) {
                        ErrorHandler.handleError(
                            'TaskSequencerHelper', 
                            'createInitialTasks', 
                            new DmlException('Partial task creation failure'), 
                            opportunities,
                            ErrorHandler.ErrorSeverity.MEDIUM,
                            new Map<String, Object>{
                                'context' => 'Task Insertion',
                                'failedTaskCount' => failedTasks.size(),
                                'successfulTaskCount' => safeTasksToCreate.size() - failedTasks.size()
                            }
                        );
                    }
                    
                } catch (DmlException dmlEx) {
                    ErrorHandler.handleError(
                        'TaskSequencerHelper', 
                        'createInitialTasks', 
                        dmlEx, 
                        opportunities,
                        ErrorHandler.ErrorSeverity.HIGH,
                        new Map<String, Object>{
                            'context' => 'Task DML Operation',
                            'taskCount' => tasksToCreate.size()
                        }
                    );
                } catch (Exception insertEx) {
                    ErrorHandler.handleError(
                        'TaskSequencerHelper', 
                        'createInitialTasks', 
                        insertEx, 
                        opportunities,
                        ErrorHandler.ErrorSeverity.HIGH,
                        new Map<String, Object>{
                            'context' => 'Task Insertion Security',
                            'taskCount' => tasksToCreate.size()
                        }
                    );
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.handleError(
                'TaskSequencerHelper', 
                'createInitialTasks', 
                e, 
                opportunities,
                ErrorHandler.ErrorSeverity.CRITICAL,
                new Map<String, Object>{
                    'processTypes' => processTypes,
                    'opportunityCount' => opportunities != null ? opportunities.size() : 0
                }
            );
        }
    }
    
    public static void handleTaskCompletion(List<Task__c> completedTasks, Set<Id> taskIds, Set<Id> processTrackIds) {
        try {
            // Bulkification check
            if (completedTasks == null || completedTasks.isEmpty() || 
                taskIds == null || taskIds.isEmpty() || 
                processTrackIds == null || processTrackIds.isEmpty()) {
                return;
            }
            
            List<Task__c> nextTasksToCreate = new List<Task__c>();
            
            // Query completed tasks with error handling
            Map<Id, Task__c> completedTasksWithDetails;
            try {
                completedTasksWithDetails = new Map<Id, Task__c>([
                    SELECT Id, Opportunity__c, Process_Track__c, Task_Sequence__c, 
                           Task_Sequence__r.Sequence_Order__c
                    FROM Task__c 
                    WHERE Id IN :taskIds
                    WITH SECURITY_ENFORCED
                ]);
            } catch (Exception queryEx) {
                ErrorHandler.handleError(
                    'TaskSequencerHelper', 
                    'handleTaskCompletion', 
                    queryEx, 
                    completedTasks,
                    ErrorHandler.ErrorSeverity.HIGH,
                    new Map<String, Object>{
                        'context' => 'Querying Completed Tasks',
                        'taskIds' => taskIds
                    }
                );
                return;
            }
            
            // Strip inaccessible fields from query results
            Map<Id, Task__c> safeCompletedTasks;
            try {
                SObjectAccessDecision taskDecision = Security.stripInaccessible(AccessType.READABLE, completedTasksWithDetails.values());
                safeCompletedTasks = new Map<Id, Task__c>((List<Task__c>)taskDecision.getRecords());
            } catch (Exception securityEx) {
                System.debug('Security strip failed, using original records: ' + securityEx.getMessage());
                safeCompletedTasks = completedTasksWithDetails;
            }
            
            // Get next sequences with error handling
            List<Task_Sequence__c> nextSequences;
            try {
                nextSequences = [
                    SELECT Id, Process_Track__c, Sequence_Order__c, Task_Name__c, Description__c, Estimated_Duration__c
                    FROM Task_Sequence__c 
                    WHERE Process_Track__c IN :processTrackIds
                    WITH SECURITY_ENFORCED
                    ORDER BY Process_Track__c, Sequence_Order__c
                    
                ];
            } catch (Exception queryEx) {
                ErrorHandler.handleError(
                    'TaskSequencerHelper', 
                    'handleTaskCompletion', 
                    queryEx, 
                    completedTasks,
                    ErrorHandler.ErrorSeverity.HIGH,
                    new Map<String, Object>{
                        'context' => 'Querying Next Sequences',
                        'processTrackIds' => processTrackIds
                    }
                );
                return;
            }
            
            // Strip inaccessible fields from query results
            List<Task_Sequence__c> safeNextSequences;
            try {
                SObjectAccessDecision sequenceDecision = Security.stripInaccessible(AccessType.READABLE, nextSequences);
                safeNextSequences = (List<Task_Sequence__c>)sequenceDecision.getRecords();
            } catch (Exception securityEx) {
                System.debug('Security strip failed, using original records: ' + securityEx.getMessage());
                safeNextSequences = nextSequences;
            }
            
            Map<String, Task_Sequence__c> sequenceMap = new Map<String, Task_Sequence__c>();
            for(Task_Sequence__c seq : safeNextSequences) {
                try {
                    if(seq.Process_Track__c != null && seq.Sequence_Order__c != null) {
                        String key = seq.Process_Track__c + '-' + seq.Sequence_Order__c;
                        sequenceMap.put(key, seq);
                    }
                } catch (Exception processingEx) {
                    System.debug('Error processing sequence ' + seq.Id + ': ' + processingEx.getMessage());
                }
            }
            
            for(Task__c completedTask : completedTasks) {
                try {
                    // Get the full task details with relationships
                    Task__c taskWithDetails = safeCompletedTasks.get(completedTask.Id);
                    
                    // Check if we have the sequence order and it's not null
                    if(taskWithDetails != null && 
                       taskWithDetails.Task_Sequence__r != null && 
                       taskWithDetails.Task_Sequence__r.Sequence_Order__c != null) {
                           
                        Decimal nextOrder = taskWithDetails.Task_Sequence__r.Sequence_Order__c + 1;
                        String nextKey = taskWithDetails.Process_Track__c + '-' + nextOrder;
                        
                        if(sequenceMap.containsKey(nextKey)) {
                            Task_Sequence__c nextSequence = sequenceMap.get(nextKey);
                            Task__c newTask = createTaskFromSequence(
                                new Opportunity(Id = taskWithDetails.Opportunity__c),
                                nextSequence,
                                taskWithDetails.Process_Track__c
                            );
                            if(newTask != null) {
                                nextTasksToCreate.add(newTask);
                            }
                        }
                    }
                } catch (Exception nextTaskEx) {
                    System.debug('Error creating next task for completed task ' + completedTask.Id + ': ' + nextTaskEx.getMessage());
                    // Continue with other completed tasks
                }
            }
            
            if(!nextTasksToCreate.isEmpty()) {
                try {
                    // Strip inaccessible fields before insert
                    SObjectAccessDecision taskInsertDecision = Security.stripInaccessible(AccessType.CREATABLE, nextTasksToCreate);
                    List<Task__c> safeNextTasksToCreate = (List<Task__c>)taskInsertDecision.getRecords();
                    
                    // Use database.insert for partial success handling
                    Database.SaveResult[] insertResults = Database.insert(safeNextTasksToCreate, false);
                    
                    // Check for individual failures
                    List<Task__c> failedTasks = new List<Task__c>();
                    for(Integer i = 0; i < insertResults.size(); i++) {
                        if(!insertResults[i].isSuccess()) {
                            failedTasks.add(safeNextTasksToCreate[i]);
                            System.debug('Failed to insert next task: ' + insertResults[i].getErrors());
                        }
                    }
                    
                    if(!failedTasks.isEmpty()) {
                        ErrorHandler.handleError(
                            'TaskSequencerHelper', 
                            'handleTaskCompletion', 
                            new DmlException('Partial next task creation failure'), 
                            completedTasks,
                            ErrorHandler.ErrorSeverity.MEDIUM,
                            new Map<String, Object>{
                                'context' => 'Next Task Insertion',
                                'failedTaskCount' => failedTasks.size(),
                                'successfulTaskCount' => safeNextTasksToCreate.size() - failedTasks.size()
                            }
                        );
                    }
                    
                } catch (DmlException dmlEx) {
                    ErrorHandler.handleError(
                        'TaskSequencerHelper', 
                        'handleTaskCompletion', 
                        dmlEx, 
                        completedTasks,
                        ErrorHandler.ErrorSeverity.HIGH,
                        new Map<String, Object>{
                            'context' => 'Next Task DML Operation',
                            'nextTaskCount' => nextTasksToCreate.size()
                        }
                    );
                } catch (Exception insertEx) {
                    ErrorHandler.handleError(
                        'TaskSequencerHelper', 
                        'handleTaskCompletion', 
                        insertEx, 
                        completedTasks,
                        ErrorHandler.ErrorSeverity.HIGH,
                        new Map<String, Object>{
                            'context' => 'Next Task Insertion Security',
                            'nextTaskCount' => nextTasksToCreate.size()
                        }
                    );
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.handleError(
                'TaskSequencerHelper', 
                'handleTaskCompletion', 
                e, 
                completedTasks,
                ErrorHandler.ErrorSeverity.CRITICAL,
                new Map<String, Object>{
                    'taskIds' => taskIds,
                    'processTrackIds' => processTrackIds,
                    'completedTaskCount' => completedTasks != null ? completedTasks.size() : 0
                }
            );
        }
    }
    
    @TestVisible
    private static Task__c createTaskFromSequence(Opportunity opp, Task_Sequence__c sequence, Id processTrackId) {
        try {
            
            
            // Calculate due date: today + Estimated_Duration__c days (excluding weekends)
            Integer durationDays = sequence.Estimated_Duration__c != null ? Integer.valueOf(sequence.Estimated_Duration__c) : 0;
            Date dueDate = calculateBusinessDate(Date.today(), durationDays);
            
            // Create task with all required fields
            Task__c newTask = new Task__c(
                Task_Name__c = sequence.Task_Name__c,
                Opportunity__c = opp.Id,
                Process_Track__c = processTrackId,
                Task_Sequence__c = sequence.Id,
                Status__c = 'Not Started',
                Description__c = sequence.Description__c,
                Due_Date__c = dueDate
            );
            
            return newTask;
            
        } catch (Exception e) {
            System.debug('Error in createTaskFromSequence for Opportunity ' + opp.Id + ': ' + e.getMessage());
            return null;
        }
    }
    @TestVisible
    private static Date calculateBusinessDate(Date startDate, Integer businessDays) {
        try {
            if (businessDays <= 0) return startDate;
            
            Date resultDate = startDate;
            Integer daysAdded = 0;
            
            while (daysAdded < businessDays) {
                resultDate = resultDate.addDays(1);
                // Check if it's a business day (Monday-Friday)
                Datetime dt = Datetime.newInstance(resultDate.year(), resultDate.month(), resultDate.day());
                String dayOfWeek = dt.format('E');
                if (dayOfWeek != 'Sat' && dayOfWeek != 'Sun') {
                    daysAdded++;
                }
            }
            
            return resultDate;
            
        } catch (Exception e) {
            System.debug('Error in calculateBusinessDate: ' + e.getMessage());
            // Fallback: return start date + business days (including weekends)
            return startDate.addDays(businessDays);
        }
    }
}