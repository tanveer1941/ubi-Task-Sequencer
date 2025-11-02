@isTest
public with sharing class TestUtility {
    
    private static Integer fakeIdCounter = 1;
    
    public static Id getFakeId(Schema.SObjectType sobjectType) {
        String keyPrefix = sobjectType.getDescribe().getKeyPrefix();
        return Id.valueOf(keyPrefix + '00000000000' + String.valueOf(fakeIdCounter++).leftPad(3, '0'));
    }
}