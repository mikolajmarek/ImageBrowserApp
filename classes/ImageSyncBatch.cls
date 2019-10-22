global class ImageSyncBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    global Integer recordsProcessed = 0;
    public String localImgQuery = 'Select id, name, title__c, Album_number__c,Image_Number__c, Miniature_Picture__c, Picture_ID__c, Picture_URL__c, Thumbnail__c FROM My_Image__c';
    final static String IMAGE_JSON_URL = 'https://jsonplaceholder.typicode.com/photos';
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        //System.debug('MJ2: inside start ' );
        return Database.getQueryLocator(localImgQuery);
        
    }

    global void execute(Database.BatchableContext BC, List<My_Image__c> imagesToSync) {        
         //System.debug('MJ2: inside execute ' + imagesToSync);
        List <ImgSyncService.RetrivedPicture> retrivedPicList = new List <ImgSyncService.RetrivedPicture>();
        List <My_Image__c> myImgToAdd = new List <My_Image__c>();
        List <My_Image__c> myImgToDelete = new List <My_Image__c>();

         Map<Decimal, My_Image__c> myImgNumberMap  = ImgSyncService.createNumberImgMap(imagesToSync);
        
            try{
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(IMAGE_JSON_URL);
                request.setMethod('GET');
                HttpResponse response = http.send(request);
                // If the request is successful, parse the JSON response.
                if (response.getStatusCode() == 200) {
            
                retrivedPicList = ImgSyncService.parseRetrivedPictureFromJSON(response.getBody());
                }
            }
            catch(Exception e){
            } 
                        
            for(ImgSyncService.RetrivedPicture pic: retrivedPicList){
                
                if(!myImgNumberMap.containsKey(Decimal.valueOf(pic.id))){
                   
                    My_Image__c newImg = new My_Image__c();
                    newImg.name = pic.url.removeStartIgnoreCase('https://via.placeholder.com/600/');
                    newImg.Image_Number__c = Decimal.valueOf(pic.id);
                    newImg.Album_number__c = Decimal.valueOf(pic.albumId);
                    newImg.Miniature_Picture__c = pic.thumbnailUrl;
                    newImg.Picture_URL__c = pic.url;
                    newImg.title__c = pic.title;
                    System.debug('MJ2: inside if ' + newImg);
                    myImgToAdd.add(newImg);
                }else if(myImgNumberMap.containsKey(Decimal.valueOf(pic.id))){
                myImgNumberMap.remove(Decimal.valueOf(pic.id));
                }
            }
            //System.debug('MJ2b: '+ myImgNumberMap);
            if(!myImgNumberMap.isEmpty()){
                myImgToDelete.addAll(myImgNumberMap.values());
            }
        If(!MyImgToAdd.isEmpty()){
            //insert MyImgToAdd;
            //System.debug('MJ2: to insert ' + MyImgToAdd);

            Database.SaveResult[] listOfInsertedMyImg = Database.insert(MyImgToAdd, false);
            
            Set<Id> picsIds = new Set<Id>();
            for(Database.SaveResult res: listOfInsertedMyImg){
                if(res.isSuccess()){
                    picsIds.add(res.getId());
                }
                //System.debug('MJ2: ids to pass ' + picsIds);
            }
          
            if(!picsIds.isEmpty()){
                Id jobId = System.enqueueJob(new ImgSyncService.QueueablePicAttach(picsIds));
                //ImgSyncService.AddPicsToAttachments(picsIds);
            }
        } 
        If(!MyImgToDelete.isEmpty()){
            //System.debug('MJ2: to delete ' + MyImgToDelete);
            delete MyImgToDelete;
            //notes will be also deleted as part of Maser-Detail relationship
        }   

    }      
   
    global void finish(Database.BatchableContext BC){   
    }

}