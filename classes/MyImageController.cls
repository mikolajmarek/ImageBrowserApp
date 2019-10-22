public with sharing class MyImageController {
    
    @AuraEnabled
    public static List<My_Image__c> getAllImages(String titleString){
        String filteredKey = sanitizeQueryString(titleString);
        return [Select id, name, title__c, Album_number__c,Image_Number__c, Miniature_Picture__c, Picture_ID__c, Picture_URL__c, Thumbnail__c FROM My_Image__c WHERE title__c!=null AND title__c LIKE:filteredKey LIMIT 30];
        
    }

    static String sanitizeQueryString(String aQuery) {
        if (aQuery == null) {
            return '%';
        }
        String trimmedQuery = aQuery.trim();
        if (trimmedQuery.length() == 0) return '%';
    
        return '%' + trimmedQuery.replaceAll('\\W+', '%') + '%';
    }
}