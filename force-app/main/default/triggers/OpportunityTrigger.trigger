trigger OpportunityTrigger on Opportunity (before update, after update) {
    // Check operation type once and handle accordingly
    if (Trigger.isUpdate) {
        switch on Trigger.operationType {
            when BEFORE_UPDATE {
                OpportunityTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
            }
            when AFTER_UPDATE {
                OpportunityTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
            }
        }
    }
}