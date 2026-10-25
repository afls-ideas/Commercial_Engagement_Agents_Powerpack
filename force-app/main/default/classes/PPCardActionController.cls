/** Server-side handler for the card's follow-up buttons, so DML errors surface as readable messages. */
public with sharing class PPCardActionController {

    @AuraEnabled
    public static Id createTask(String subject, Id whatId, Integer dueInDays, Boolean highPriority) {
        try {
            Task t = new Task(
                Subject = subject == null ? 'Follow up' : subject.left(255),
                ActivityDate = Date.today().addDays(dueInDays == null ? 3 : dueInDays),
                Priority = highPriority == true ? 'High' : 'Normal',
                Status = 'Not Started',
                OwnerId = UserInfo.getUserId());
            if (whatId != null) t.WhatId = whatId;
            insert t;
            return t.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
