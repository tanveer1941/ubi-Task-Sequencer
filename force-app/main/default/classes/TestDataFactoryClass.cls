@isTest
public with sharing class TestDataFactoryClass {
    
    // Constants for default values
    private static final String DEFAULT_STAGE = 'Prospecting';
    private static final Integer DEFAULT_AMOUNT = 50000;
    private static final Integer DEFAULT_CLOSE_DATE_DAYS = 30;
    private static final String DEFAULT_TASK_STATUS = 'Not Started';
    
    // Create Opportunities with enhanced flexibility
    public static List<Opportunity> createOpportunities(Integer numOpps, String stageName, Boolean doInsert) {
        if (numOpps == null || numOpps <= 0) {
            return new List<Opportunity>();
        }
        
        List<Opportunity> opportunities = new List<Opportunity>();
        Date closeDate = Date.today().addDays(DEFAULT_CLOSE_DATE_DAYS);
        String actualStage = String.isNotBlank(stageName) ? stageName : DEFAULT_STAGE;
        
        for(Integer i = 0; i < numOpps; i++) {
            opportunities.add(new Opportunity(
                Name = 'Test Opportunity ' + i + ' ' + System.currentTimeMillis(),
                StageName = actualStage,
                CloseDate = closeDate,
                Amount = DEFAULT_AMOUNT + (i * 1000)
            ));
        }
        
        return doInsert ? safelyInsertOpportunities(opportunities) : opportunities;
    }
    
    public static Opportunity createOpportunity(Boolean doInsert) {
        return createOpportunity(doInsert, null);
    }
    
    public static Opportunity createOpportunity(Boolean doInsert, Map<String, Object> additionalFields) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity ' + System.currentTimeMillis(),
            StageName = DEFAULT_STAGE,
            CloseDate = Date.today().addDays(DEFAULT_CLOSE_DATE_DAYS),
            Amount = DEFAULT_AMOUNT
        );
        
        // Apply additional fields if provided
        if (additionalFields != null) {
            for (String fieldName : additionalFields.keySet()) {
                opp.put(fieldName, additionalFields.get(fieldName));
            }
        }
        
        return doInsert ? safelyInsertOpportunities(new List<Opportunity>{opp})[0] : opp;
    }
    
    // Create Process Tracks with validation (REMOVED Name field)
    public static List<Process_Track__c> createProcessTracks(List<String> processTypes, Boolean doInsert) {
        if (processTypes == null || processTypes.isEmpty()) {
            return new List<Process_Track__c>();
        }
        
        List<Process_Track__c> processTracks = new List<Process_Track__c>();
        Set<String> uniqueTypes = new Set<String>();
        
        for(String processType : processTypes) {
            if (String.isNotBlank(processType) && !uniqueTypes.contains(processType)) {
                uniqueTypes.add(processType);
                processTracks.add(new Process_Track__c(
                    // Name field removed - it's auto-generated
                    Type__c = processType,
                    Description__c = 'Test description for ' + processType
                ));
            }
        }
        
        return doInsert ? safelyInsertProcessTracks(processTracks) : processTracks;
    }
    
    public static Process_Track__c createProcessTrack(String processType, Boolean doInsert) {
        return createProcessTrack(processType, doInsert, null);
    }
    
    public static Process_Track__c createProcessTrack(String processType, Boolean doInsert, Map<String, Object> additionalFields) {
        if (String.isBlank(processType)) {
            processType = getRandomProcessType();
        }
        
        Process_Track__c track = new Process_Track__c(
            // Name field removed - it's auto-generated
            Type__c = processType,
            Description__c = 'Test description for ' + processType
        );
        
        if (additionalFields != null) {
            for (String fieldName : additionalFields.keySet()) {
                track.put(fieldName, additionalFields.get(fieldName));
            }
        }
        
        return doInsert ? safelyInsertProcessTracks(new List<Process_Track__c>{track})[0] : track;
    }
    
    // Create Task Sequences with validation (REMOVED Name field)
    public static List<Task_Sequence__c> createTaskSequences(Id processTrackId, Integer numSequences, Boolean doInsert) {
        if (processTrackId == null || numSequences == null || numSequences <= 0) {
            return new List<Task_Sequence__c>();
        }
        
        List<Task_Sequence__c> sequences = new List<Task_Sequence__c>();
        
        for(Integer i = 1; i <= numSequences; i++) {
            sequences.add(new Task_Sequence__c(
                // Name field removed - it's auto-generated
                Process_Track__c = processTrackId,
                Sequence_Order__c = i,
                Task_Name__c = 'Test Task ' + i,
                Description__c = 'Test description for task ' + i,
                Estimated_Duration__c = i * 2 // 2, 4, 6 days etc.
            ));
        }
        
        return doInsert ? safelyInsertTaskSequences(sequences) : sequences;
    }
    
    public static List<Task_Sequence__c> createTaskSequences(List<Process_Track__c> processTracks, Integer sequencesPerTrack, Boolean doInsert) {
        if (processTracks == null || processTracks.isEmpty() || sequencesPerTrack == null || sequencesPerTrack <= 0) {
            return new List<Task_Sequence__c>();
        }
        
        List<Task_Sequence__c> allSequences = new List<Task_Sequence__c>();
        
        for(Process_Track__c track : processTracks) {
            if (track.Id != null) {
                List<Task_Sequence__c> trackSequences = createTaskSequences(track.Id, sequencesPerTrack, false);
                allSequences.addAll(trackSequences);
            }
        }
        
        return (doInsert && !allSequences.isEmpty()) ? safelyInsertTaskSequences(allSequences) : allSequences;
    }
    
    // Create Tasks with enhanced flexibility
    public static List<Task__c> createTasks(List<Opportunity> opportunities, Id processTrackId, Id taskSequenceId, Integer numTasks, Boolean doInsert) {
        if (opportunities == null || opportunities.isEmpty() || numTasks == null || numTasks <= 0) {
            return new List<Task__c>();
        }
        
        List<Task__c> tasks = new List<Task__c>();
        
        for(Opportunity opp : opportunities) {
            if (opp.Id != null) {
                for(Integer i = 0; i < numTasks; i++) {
                    tasks.add(new Task__c(
                        Task_Name__c = 'Test Task ' + i + ' for ' + opp.Name,
                        Opportunity__c = opp.Id,
                        Process_Track__c = processTrackId,
                        Task_Sequence__c = taskSequenceId,
                        Status__c = DEFAULT_TASK_STATUS,
                        Description__c = 'Test task description',
                        Due_Date__c = Date.today().addDays(7)
                    ));
                }
            }
        }
        
        return doInsert ? safelyInsertTasks(tasks) : tasks;
    }
    
    public static Task__c createTask(Id opportunityId, Id processTrackId, Id taskSequenceId, String status, Boolean doInsert) {
        return createTask(opportunityId, processTrackId, taskSequenceId, status, doInsert, null);
    }
    
    public static Task__c createTask(Id opportunityId, Id processTrackId, Id taskSequenceId, String status, Boolean doInsert, Map<String, Object> additionalFields) {
        if (opportunityId == null) {
            return null;
        }
        
        Task__c task = new Task__c(
            Task_Name__c = 'Test Task ' + System.currentTimeMillis(),
            Opportunity__c = opportunityId,
            Process_Track__c = processTrackId,
            Task_Sequence__c = taskSequenceId,
            Status__c = String.isNotBlank(status) ? status : DEFAULT_TASK_STATUS,
            Description__c = 'Test task description',
            Due_Date__c = Date.today().addDays(7)
        );
        
        if (additionalFields != null) {
            for (String fieldName : additionalFields.keySet()) {
                task.put(fieldName, additionalFields.get(fieldName));
            }
        }
        
        return doInsert ? safelyInsertTasks(new List<Task__c>{task})[0] : task;
    }
    
    // Create complete test scenario with error handling
    public static TestScenario createCompleteScenario(String processType, Integer numOpportunities, Integer numSequences) {
        TestScenario scenario = new TestScenario();
        
        try {
            // Create opportunities
            scenario.opportunities = createOpportunities(numOpportunities, DEFAULT_STAGE, true);
            
            if (scenario.opportunities.isEmpty()) {
                return scenario;
            }
            
            // Create process track
            scenario.processTrack = createProcessTrack(processType, true);
            
            if (scenario.processTrack.Id == null) {
                return scenario;
            }
            
            // Create task sequences
            scenario.taskSequences = createTaskSequences(scenario.processTrack.Id, numSequences, true);
            
        } catch (Exception e) {
            System.debug('Error creating complete scenario: ' + e.getMessage());
        }
        
        return scenario;
    }
    
    // Safe insert methods with proper type casting
    private static List<Opportunity> safelyInsertOpportunities(List<Opportunity> records) {
        if (records == null || records.isEmpty()) {
            return records;
        }
        
        try {
            insert records;
            return records;
        } catch (DmlException e) {
            System.debug('Error inserting opportunities: ' + e.getMessage());
            return records;
        }
    }
    
    private static List<Process_Track__c> safelyInsertProcessTracks(List<Process_Track__c> records) {
        if (records == null || records.isEmpty()) {
            return records;
        }
        
        try {
            insert records;
            return records;
        } catch (DmlException e) {
            System.debug('Error inserting process tracks: ' + e.getMessage());
            return records;
        }
    }
    
    private static List<Task_Sequence__c> safelyInsertTaskSequences(List<Task_Sequence__c> records) {
        if (records == null || records.isEmpty()) {
            return records;
        }
        
        try {
            insert records;
            return records;
        } catch (DmlException e) {
            System.debug('Error inserting task sequences: ' + e.getMessage());
            return records;
        }
    }
    
    private static List<Task__c> safelyInsertTasks(List<Task__c> records) {
        if (records == null || records.isEmpty()) {
            return records;
        }
        
        try {
            insert records;
            return records;
        } catch (DmlException e) {
            System.debug('Error inserting tasks: ' + e.getMessage());
            return records;
        }
    }
    
    // Get a random process type from available picklist values
    public static String getRandomProcessType() {
        List<String> processTypes = getProcessPicklistValues();
        return processTypes.isEmpty() ? 'Site_Survey' : processTypes[0];
    }
    
    // Get process types dynamically from Opportunity.Process__c picklist
    public static List<String> getProcessPicklistValues() {
        List<String> picklistValues = new List<String>();
        
        try {
            Schema.DescribeFieldResult fieldResult = Opportunity.Process__c.getDescribe();
            if (fieldResult != null) {
                List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
                
                for(Schema.PicklistEntry entry : ple) {
                    if(entry.isActive()) {
                        picklistValues.add(entry.getValue());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error getting picklist values: ' + e.getMessage());
            // Return default values if picklist is not accessible
            picklistValues.add('Site_Survey');
            picklistValues.add('Installation');
            picklistValues.add('Grid_Connection');
        }
        
        return picklistValues;
    }
    
    // Setup method for common test data
    public static void setupBaseData() {
        // Create process tracks for all available picklist values
        createProcessTracks(getProcessPicklistValues(), true);
    }
    
    // Wrapper class for test scenarios
    public class TestScenario {
        public List<Opportunity> opportunities;
        public Process_Track__c processTrack;
        public List<Task_Sequence__c> taskSequences;
        public List<Task__c> tasks;
    }
    
    // Method to create error scenario for testing error handling
    public static TestScenario createErrorScenario() {
        TestScenario scenario = new TestScenario();
        
        // Create opportunity with error-triggering name
        scenario.opportunities = new List<Opportunity>{
            createOpportunity(false, new Map<String, Object>{
                'Name' => 'TEST_ERROR_OPPORTUNITY'
            })
        };
        
        return scenario;
    }
    
    // Bulk data creation for performance testing
    public static TestScenario createBulkScenario(Integer numOpportunities, Integer numSequences) {
        TestScenario scenario = new TestScenario();
        
        // Create opportunities in bulk
        scenario.opportunities = createOpportunities(numOpportunities, DEFAULT_STAGE, true);
        
        // Create multiple process tracks
        List<Process_Track__c> tracks = createProcessTracks(getProcessPicklistValues(), true);
        
        if (!tracks.isEmpty()) {
            scenario.processTrack = tracks[0];
            scenario.taskSequences = createTaskSequences(scenario.processTrack.Id, numSequences, true);
        }
        
        return scenario;
    }
}