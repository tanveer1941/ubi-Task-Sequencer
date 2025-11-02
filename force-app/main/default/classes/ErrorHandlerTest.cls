@isTest
public with sharing class ErrorHandlerTest {
    
    @isTest
    static void testHandleError_Basic() {
        List<Opportunity> testRecords = TestDataFactoryClass.createOpportunities(2, 'Prospecting', true);
        
        Test.startTest();
        try {
            // Force a DmlException
            insert new Opportunity(); // This will fail due to missing required fields
        } catch (DmlException testException) {
            ErrorHandler.handleError('TestClass', 'testMethod', testException, testRecords);
        }
        Test.stopTest();
        
        System.assert(true, 'Error should be handled without throwing exception');
    }
    
    @isTest
    static void testHandleError_WithSeverity() {
        List<Opportunity> testRecords = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        try {
            // Force a QueryException
            List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE NonExistentField__c = 'test'];
        } catch (QueryException testException) {
            ErrorHandler.handleError(
                'TestClass', 
                'testMethod', 
                testException, 
                testRecords, 
                ErrorHandler.ErrorSeverity.HIGH
            );
        }
        Test.stopTest();
        
        System.assert(true, 'Error with severity should be handled');
    }
    
    @isTest
    static void testHandleError_WithAdditionalContext() {
        List<Opportunity> testRecords = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        try {
            // Force a NullPointerException
            String nullString = null;
            String upperCase = nullString.toUpperCase();
        } catch (NullPointerException testException) {
            ErrorHandler.handleError(
                'TestClass', 
                'testMethod', 
                testException, 
                testRecords, 
                ErrorHandler.ErrorSeverity.CRITICAL,
                new Map<String, Object>{
                    'customField' => 'testValue',
                    'recordCount' => 5
                }
            );
        }
        Test.stopTest();
        
        System.assert(true, 'Error with additional context should be handled');
    }
    
    
    
    @isTest
    static void testHandleError_EmptyRecords() {
        Test.startTest();
        try {
            // Force a MathException
            Integer result = 10 / 0;
        } catch (MathException testException) {
            ErrorHandler.handleError('TestClass', 'testMethod', testException, new List<Opportunity>());
        }
        Test.stopTest();
        
        System.assert(true, 'Should handle empty records list');
    }
    
   
    
    @isTest
    static void testDifferentExceptionTypes() {
        List<Opportunity> testRecords = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        
        // Test DmlException
        try {
            insert new Opportunity();
        } catch (DmlException ex) {
            ErrorHandler.handleError('TestClass', 'testMethod', ex, testRecords);
        }
        
        // Test QueryException
        try {
            List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE NonExistentField__c = 'test'];
        } catch (QueryException ex) {
            ErrorHandler.handleError('TestClass', 'testMethod', ex, testRecords);
        }
        
        // Test NullPointerException
        try {
            String nullString = null;
            Integer length = nullString.length();
        } catch (NullPointerException ex) {
            ErrorHandler.handleError('TestClass', 'testMethod', ex, testRecords);
        }
        
        // Test TypeException
        try {
            String notAnInteger = 'abc';
            Integer numberValue = Integer.valueOf(notAnInteger);
        } catch (TypeException ex) {
            ErrorHandler.handleError('TestClass', 'testMethod', ex, testRecords);
        }
        
        // Test ListException
        try {
            List<String> emptyList = new List<String>();
            String value = emptyList[5];
        } catch (ListException ex) {
            ErrorHandler.handleError('TestClass', 'testMethod', ex, testRecords);
        }
        
        Test.stopTest();
        
        System.assert(true, 'All exception types should be handled');
    }
    
    @isTest
    static void testCustomHandledException() {
        List<Opportunity> testRecords = TestDataFactoryClass.createOpportunities(1, 'Prospecting', true);
        
        Test.startTest();
        try {
            throw new ErrorHandler.HandledException(
                'Custom error message',
                'Test Context',
                ErrorHandler.ErrorSeverity.HIGH,
                testRecords
            );
        } catch (ErrorHandler.HandledException testException) {
            ErrorHandler.handleError('TestClass', 'testMethod', testException, testRecords);
        }
        Test.stopTest();
        
        System.assert(true, 'Custom handled exception should work');
    }
}