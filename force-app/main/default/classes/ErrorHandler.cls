public with sharing class ErrorHandler {
    
    // Enum for different error severity levels
    public enum ErrorSeverity {
        LOW,
        MEDIUM, 
        HIGH,
        CRITICAL
    }
    
    // Custom exception class for wrapped errors
    public class HandledException extends Exception {
        public String context;
        public ErrorSeverity severity;
        public List<SObject> affectedRecords;
        
        public HandledException(String message, String context, ErrorSeverity severity, List<SObject> affectedRecords) {
            this.setMessage(message);
            this.context = context;
            this.severity = severity;
            this.affectedRecords = affectedRecords;
        }
    }
    
    // Main error handling method
    public static void handleError(String className, String methodName, Exception e, List<SObject> affectedRecords) {
        handleError(className, methodName, e, affectedRecords, ErrorSeverity.MEDIUM, null);
    }
    
    public static void handleError(String className, String methodName, Exception e, List<SObject> affectedRecords, ErrorSeverity severity) {
        handleError(className, methodName, e, affectedRecords, severity, null);
    }
    
    public static void handleError(String className, String methodName, Exception e, List<SObject> affectedRecords, ErrorSeverity severity, Map<String, Object> additionalContext) {
        try {
            // Log the error
            logError(className, methodName, e, affectedRecords, severity, additionalContext);
            
            // Send notifications based on severity
            if (shouldSendNotification(severity)) {
                sendNotifications(className, methodName, e, affectedRecords, severity, additionalContext);
            }
            
            // Add field errors for before trigger context
            addFieldErrorsIfApplicable(e, affectedRecords);
            
        } catch (Exception handlerEx) {
            // Fallback logging if error handler itself fails
            System.debug(LoggingLevel.ERROR, 'ErrorHandler failed: ' + handlerEx.getMessage() + 
                        ' Original error: ' + e.getMessage());
        }
    }
    
    private static void logError(String className, String methodName, Exception e, List<SObject> affectedRecords, ErrorSeverity severity, Map<String, Object> additionalContext) {
        String logMessage = buildLogMessage(className, methodName, e, affectedRecords, severity, additionalContext);
        
        // Use appropriate logging level based on severity
        LoggingLevel logLevel = getLoggingLevel(severity);
        System.debug(logLevel, logMessage);
        
        
    }
    
    private static String buildLogMessage(String className, String methodName, Exception e, List<SObject> affectedRecords, ErrorSeverity severity, Map<String, Object> additionalContext) {
        String message = 'ERROR HANDLED:\n';
        message += 'Class: ' + className + '\n';
        message += 'Method: ' + methodName + '\n';
        message += 'Severity: ' + severity + '\n';
        message += 'Exception Type: ' + e.getTypeName() + '\n';
        message += 'Message: ' + e.getMessage() + '\n';
        message += 'Stack Trace: ' + e.getStackTraceString() + '\n';
        message += 'Line: ' + e.getLineNumber() + '\n';
        message += 'Time: ' + System.now() + '\n';
        
        if (affectedRecords != null && !affectedRecords.isEmpty()) {
            message += 'Affected Records: ' + affectedRecords.size() + '\n';
            message += 'Record Types: ' + getRecordTypes(affectedRecords) + '\n';
            message += 'Record IDs: ' + getRecordIds(affectedRecords) + '\n';
        }
        
        if (additionalContext != null && !additionalContext.isEmpty()) {
            message += 'Additional Context: ' + JSON.serializePretty(additionalContext) + '\n';
        }
        
        return message;
    }
    
    private static void sendNotifications(String className, String methodName, Exception e, List<SObject> affectedRecords, ErrorSeverity severity, Map<String, Object> additionalContext) {
        // Determine notification recipients based on object type and severity
        Set<String> recipientEmails = getNotificationRecipients(className, affectedRecords, severity);
        
        if (recipientEmails.isEmpty()) {
            return;
        }
        
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>(recipientEmails));
            mail.setSubject(buildEmailSubject(className, methodName, severity));
            mail.setPlainTextBody(buildEmailBody(className, methodName, e, affectedRecords, severity, additionalContext));
            
            
            
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }
            
        } catch (Exception emailEx) {
            System.debug('Failed to send error notification email: ' + emailEx.getMessage());
        }
    }
    
    private static Set<String> getNotificationRecipients(String className, List<SObject> affectedRecords, ErrorSeverity severity) {
        Set<String> emails = new Set<String>();
        
        
        // Add record-specific owners for high severity errors
        if (severity == ErrorSeverity.HIGH || severity == ErrorSeverity.CRITICAL) {
            emails.addAll(getRecordOwnerEmails(affectedRecords));
        }
        
        return emails;
    }
    
    
    
    private static Set<String> getRecordOwnerEmails(List<SObject> records) {
        Set<String> ownerEmails = new Set<String>();
        Set<Id> ownerIds = new Set<Id>();
        
        if (records == null || records.isEmpty()) {
            return ownerEmails;
        }
        
        // Extract owner IDs from records
        for (SObject record : records) {
            if (record.get('OwnerId') != null) {
                ownerIds.add((Id)record.get('OwnerId'));
            }
        }
        
        if (ownerIds.isEmpty()) {
            return ownerEmails;
        }
        
        // Query user emails
        try {
            for (User u : [SELECT Email FROM User WHERE Id IN :ownerIds AND IsActive = true AND Email != null]) {
                ownerEmails.add(u.Email);
            }
        } catch (Exception e) {
            System.debug('Failed to query owner emails: ' + e.getMessage());
        }
        
        return ownerEmails;
    }
    
    private static String buildEmailSubject(String className, String methodName, ErrorSeverity severity) {
        return 'Salesforce Error - ' + severity + ' - ' + className + '.' + methodName;
    }
    
    private static String buildEmailBody(String className, String methodName, Exception e, List<SObject> affectedRecords, ErrorSeverity severity, Map<String, Object> additionalContext) {
        String body = 'Salesforce Automation Error Notification\n\n';
        body += 'Severity: ' + severity + '\n';
        body += 'Class: ' + className + '\n';
        body += 'Method: ' + methodName + '\n';
        body += 'Time: ' + System.now() + '\n\n';
        
        body += 'Error Details:\n';
        body += '--------------\n';
        body += 'Type: ' + e.getTypeName() + '\n';
        body += 'Message: ' + e.getMessage() + '\n\n';
        
        if (affectedRecords != null && !affectedRecords.isEmpty()) {
            body += 'Affected Records: ' + affectedRecords.size() + '\n';
            body += 'Record Types: ' + getRecordTypes(affectedRecords) + '\n';
            body += 'Record IDs: ' + getRecordIds(affectedRecords) + '\n\n';
        }
        
        body += 'Recommended Action:\n';
        body += '------------------\n';
        body += getActionRecommendation(severity, e) + '\n\n';
        
        body += 'Please contact Salesforce support if you need assistance.\n\n';
        body += 'This is an automated message.';
        
        return body;
    }
    
    private static void addFieldErrorsIfApplicable(Exception e, List<SObject> affectedRecords) {
        // Only add field errors in before trigger context
        if (Trigger.isBefore && affectedRecords != null) {
            String userMessage = getFriendlyUserMessage(e);
            for (SObject record : affectedRecords) {
                try {
                    record.addError(userMessage);
                } catch (Exception addErrorEx) {
                    // Ignore errors when adding errors (meta-error!)
                }
            }
        }
    }
    
    private static String getFriendlyUserMessage(Exception e) {
        if (e instanceof System.DmlException) {
            return 'Data update failed. Please check your input and try again.';
        } else if (e instanceof System.QueryException) {
            return 'Unable to access required data. Please contact your administrator.';
        } else if (e instanceof System.SecurityException) {
            return 'Insufficient permissions to perform this action.';
        } else if (e instanceof System.LimitException) {
            return 'System limits exceeded. Please try again with fewer records.';
        } else if (e instanceof NullPointerException) {
            return 'System error: Missing required information.';
        } else {
            return 'An unexpected error occurred. Please try again or contact your administrator.';
        }
    }
    
    private static String getActionRecommendation(ErrorSeverity severity, Exception e) {
        if (severity == ErrorSeverity.CRITICAL) {
            return 'IMMEDIATE ACTION REQUIRED: Contact Salesforce administrator immediately. System functionality may be impacted.';
        } else if (severity == ErrorSeverity.HIGH) {
            return 'Review required: Check affected records and verify data integrity. Contact admin if issue persists.';
        } else if (e instanceof System.LimitException) {
            return 'Try processing fewer records at once or optimize your data operations.';
        } else {
            return 'Monitor the situation. If errors persist, contact your administrator.';
        }
    }
    
    // Utility methods
    private static LoggingLevel getLoggingLevel(ErrorSeverity severity) {
        switch on severity {
            when CRITICAL, HIGH {
                return LoggingLevel.ERROR;
            }
            when MEDIUM {
                return LoggingLevel.WARN;
            }
            when LOW {
                return LoggingLevel.DEBUG;
            }
            when else {
                return LoggingLevel.INFO;
            }
        }
    }
    
    private static Boolean shouldSendNotification(ErrorSeverity severity) {
        // Customize based on your notification preferences
        return severity == ErrorSeverity.HIGH || severity == ErrorSeverity.CRITICAL;
    }
    
    private static Boolean shouldPersistLog(ErrorSeverity severity) {
        // Customize based on your logging preferences
        return severity == ErrorSeverity.CRITICAL;
    }
    
    private static String getRecordTypes(List<SObject> records) {
        Set<String> types = new Set<String>();
        for (SObject record : records) {
            types.add(record.getSObjectType().getDescribe().getName());
        }
        return String.join(new List<String>(types), ', ');
    }
    
    private static String getRecordIds(List<SObject> records) {
        List<String> ids = new List<String>();
        for (SObject record : records) {
            ids.add(record.Id);
        }
        return String.join(ids, ', ');
    }
    
    
    
    // Convenience method for common trigger handler usage
    public static void handleTriggerError(String className, String methodName, Exception e, List<SObject> affectedRecords) {
        ErrorSeverity severity = determineSeverityFromException(e);
        handleError(className, methodName, e, affectedRecords, severity);
    }
    
    private static ErrorSeverity determineSeverityFromException(Exception e) {
        if (e instanceof System.LimitException || e instanceof System.SecurityException) {
            return ErrorSeverity.HIGH;
        } else if (e instanceof NullPointerException) {
            return ErrorSeverity.MEDIUM;
        } else {
            return ErrorSeverity.MEDIUM;
        }
    }
}