trigger TaskTrigger on Task__c  (after update) {
    if(Trigger.isAfter && Trigger.isUpdate) {
        TaskTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}