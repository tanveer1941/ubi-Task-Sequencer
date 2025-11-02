public with sharing class TaskTriggerHandler {
    
    public static void handleAfterUpdate(List<Task__c> newList, Map<Id, Task__c> oldMap) {
        try {
            // null check
            if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
                return;
            }
            
            List<Task__c> completedTasks = new List<Task__c>();
            Set<Id> taskIds = new Set<Id>();
            Set<Id> processTrackIds = new Set<Id>();
            Set<Id> opportunityIds = new Set<Id>();
            
            for(Task__c newTask : newList) {
                try {
                    Task__c oldTask = oldMap.get(newTask.Id);
                    if(newTask.Status__c == 'Completed' && oldTask.Status__c != 'Completed') {
                        completedTasks.add(newTask);
                        taskIds.add(newTask.Id);
                        if(newTask.Process_Track__c != null) {
                            processTrackIds.add(newTask.Process_Track__c);
                        }
                        if(newTask.Opportunity__c != null) {
                            opportunityIds.add(newTask.Opportunity__c);
                        }
                    }
                } catch (Exception e) {
                    // Handle individual task processing errors
                    System.debug('Error processing Task ' + newTask.Id + ': ' + e.getMessage());
                    // Continue processing other tasks
                }
            }
            
            if(!completedTasks.isEmpty() && !taskIds.isEmpty()) {
                TaskSequencerHelper.handleTaskCompletion(completedTasks, taskIds, processTrackIds);
            }
            
        } catch (Exception e) {
            ErrorHandler.handleTriggerError('TaskTriggerHandler', 'handleAfterUpdate', e, newList);
        }
    }
}