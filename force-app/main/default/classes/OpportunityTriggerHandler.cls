public with sharing class OpportunityTriggerHandler {
    
    public static void handleBeforeUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        try {
            // null check
            if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
                return;
            }
            
            validateProcessChange(newList, oldMap);
            
        } catch (Exception e) {
            ErrorHandler.handleTriggerError('OpportunityTriggerHandler', 'handleBeforeUpdate', e, newList);
        }
    }
    
    public static void handleAfterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        try {
            // null check
            if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
                return;
            }
            
            List<Opportunity> processChangedOpps = new List<Opportunity>();
            Set<String> processTypes = new Set<String>();
            
            for(Opportunity newOpp : newList) {
                try {
                    Opportunity oldOpp = oldMap.get(newOpp.Id);
                    if(newOpp.Process__c != oldOpp.Process__c && newOpp.Process__c != null) {
                        processChangedOpps.add(newOpp);
                        processTypes.add(newOpp.Process__c);
                    }
                } catch (Exception e) {
                    // Individual record processing errors
                    System.debug('Error processing Opportunity ' + newOpp.Id + ': ' + e.getMessage());
                    // Code must continue processing for other records
                }
            }
            
            if(!processChangedOpps.isEmpty() && !processTypes.isEmpty()) {
                TaskSequencerHelper.createInitialTasks(processChangedOpps, processTypes);
            }
            
        } catch (Exception e) {
            ErrorHandler.handleTriggerError('OpportunityTriggerHandler', 'handleAfterUpdate', e, newList);
        }
    }
    
    private static void validateProcessChange(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        try {
            Set<Id> opportunityIds = new Set<Id>();
            Map<Id, Opportunity> processChangedOpps = new Map<Id, Opportunity>();
            
            // Identify opportunities where the process is changed
            for(Opportunity newOpp : newList) {
                try {
                    Opportunity oldOpp = oldMap.get(newOpp.Id);
                    if(newOpp.Process__c != oldOpp.Process__c) {
                        opportunityIds.add(newOpp.Id);
                        processChangedOpps.put(newOpp.Id, newOpp);
                    }
                } catch (Exception e) {
                    System.debug('Error validating process change for Opportunity ' + newOpp.Id + ': ' + e.getMessage());
                    // Add validation error for user
                    newOpp.addError('Error validating process change. Please contact your administrator.');
                }
            }
            
            if(opportunityIds.isEmpty()) return;
            
            List<Task__c> tasks;
            try {
                // Querying tasks with security enforcement
                tasks = [
                    SELECT Id, Opportunity__c 
                    FROM Task__c 
                    WHERE Opportunity__c IN :opportunityIds 
                    AND Status__c != 'Completed'
                    WITH SECURITY_ENFORCED
                ];
            } catch (System.QueryException e) {
                // Handle query exceptions (if the object or field is not accessible)
                System.debug('QueryException in validateProcessChange: ' + e.getMessage());
                for(Id oppId : processChangedOpps.keySet()) {
                    processChangedOpps.get(oppId).addError('Unable to validate process change due to system error. Please try again.');
                }
                return;
            } catch (Exception e) {
                System.debug('Unexpected task query error: ' + e.getMessage());
                for(Id oppId : processChangedOpps.keySet()) {
                    processChangedOpps.get(oppId).addError('System error during validation. Please contact your administrator.');
                }
                return;
            }
            
            // Strip inaccessible fields from query results | filtering records here which are readable for user
            List<Task__c> safeTasks;
            try {
                SObjectAccessDecision taskDecision = Security.stripInaccessible(AccessType.READABLE, tasks);
                safeTasks = (List<Task__c>)taskDecision.getRecords();
            } catch (Exception e) {
                System.debug('Error in stripInaccessible: ' + e.getMessage());
                // Fallback to original tasks if security check fails
                safeTasks = tasks;
            }
            
            // Count tasks per opportunity
            Map<Id, Integer> oppTaskCount = new Map<Id, Integer>();
            for(Task__c task : safeTasks) {
                try {
                    if(task.Opportunity__c != null) {
                        Integer currentCount = oppTaskCount.get(task.Opportunity__c) != null ? 
                            oppTaskCount.get(task.Opportunity__c) : 0;
                        oppTaskCount.put(task.Opportunity__c, currentCount + 1);
                    }
                } catch (Exception e) {
                    System.debug('Error counting tasks for Opportunity ' + task.Opportunity__c + ': ' + e.getMessage());
                    // Continue processing other tasks
                }
            }
            
            // Add validation errors if tasks exist
            for(Opportunity newOpp : newList) {
                try {
                    if(processChangedOpps.containsKey(newOpp.Id)) {
                        Integer taskCount = oppTaskCount.get(newOpp.Id);
                        if(taskCount != null && taskCount > 0) {
                            newOpp.addError('Cannot change Process while active tasks exist. Please complete all tasks first.');
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error adding validation error to Opportunity ' + newOpp.Id + ': ' + e.getMessage());
                    newOpp.addError('Validation error occurred. Please contact your administrator.');
                }
            }
            
        } catch (Exception e) {
            // Catch any unhandled exceptions in the main method
            System.debug('Unhandled error in validateProcessChange: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            for(Opportunity newOpp : newList) {
                newOpp.addError('System error during process validation. Please contact your administrator.');
            }
            throw e; // Re-throwing to be caught by outer try-catch block
        }
    }
    
}