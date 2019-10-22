public with sharing class ImgSyncService {
    public ImgSyncService() {

    }

    final static String IMAGE_JSON_URL = 'https://jsonplaceholder.typicode.com/photos';
    final static String TEST_JSON = '[{ "albumId": 1,    "id": 1,    "title": "accusamus beatae ad facilis cum similique qui sunt",    "url": "https://via.placeholder.com/600/92c952",    "thumbnailUrl": "https://via.placeholder.com/150/92c952"  },      {    "albumId": 1,    "id": 2,    "title": "reprehenderit est deserunt velit ipsam",    "url": "https://via.placeholder.com/600/771796",    "thumbnailUrl": "https://via.placeholder.com/150/771796"  }]';

    public class RetrivedPicture {
        public String albumId;
        public String id;
        public String title;
        public String url;
        public String thumbnailUrl;
        
    }

    public static List<RetrivedPicture> parseRetrivedPictureFromJSON(String retrivedJSON){

         List<RetrivedPicture> retrivedPics = (List<RetrivedPicture>) System.JSON.deserialize(retrivedJSON, List<RetrivedPicture>.class);
        
        Integer i = 0;
        For(RetrivedPicture retrPIc: retrivedPics){
            if(i <10){
                //System.debug(retrPIc);
            i++;
            }
        }
        
        return retrivedPics;          
    }
    
    public static Map<Decimal, My_Image__c> createNumberImgMap (List <My_Image__c> images){
        Map<Decimal, My_Image__c> myImgNumberMap = new Map<Decimal, My_Image__c>();
        for(My_Image__c img: images){
            myImgNumberMap.put(img.Image_Number__c, img);

        }
        return myImgNumberMap;
    }
    
    public class QueueablePicAttach implements Queueable, Database.AllowsCallouts { 	    
        Set<Id> AttachementIds = new Set<Id>();
        private Set<id> picIds;
        private Set<id> first75Ids =new Set<Id>();
        Boolean insertNotSuccesful = false;
        public QueueablePicAttach(Set <id> picIds){
            this.picIds = picIds;
        }
        
        public void execute(QueueableContext context) {
            if(picIds.size()>75){
                Integer i = 0;
                for(Id picId: picIds){
                    i++;
                    If(i<75){
                       first75Ids.add(picId);
                       picIds.remove(picId); 
                    }                    
                }
            }else {
                first75Ids.addAll(picIds);
                picIds.clear();
            }	 
            //System.debug('Mj set of ids in queable' + picIds);       
                Map<id, My_Image__c> imagesMissingAttachements = new Map<id, My_Image__c>([SELECT id, name, Picture_URL__c, Miniature_Picture__c from My_Image__c WHERE id IN:first75Ids LIMIT 150]);
    //System.debug('Mj set of ids in map' + imagesMissingAttachements);
    List<Attachment> attachments = new List<Attachment>(); 
    for(My_Image__c pic: imagesMissingAttachements.values()){
        //System.debug('inside for ' + pic);
    
        try{        
                if(pic.Picture_URL__c!=null){
        //System.debug('inside if 1' + pic);

                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(pic.Picture_URL__c);
                request.setMethod('GET');
                request.setHeader('Content-Type', 'image/jpeg');
                request.setCompressed(true);
                request.setTimeout(60000);
                HttpResponse response = http.send(request);
                    //System.debug('response ' + response.getStatusCode());
                    if (response.getStatusCode() == 200) {
                        blob image = response.getBodyAsBlob();
                        Attachment attachedPic = new Attachment(); 
                        attachedPic.ParentId = pic.Id; 
                        attachedPic.Name = pic.Picture_URL__c.removeStartIgnoreCase('https://via.placeholder.com/600/')+'_600dpi';
                         
                        attachedPic.contentType = 'image/jpeg';
                        attachedPic.Body = image;  
                        attachments.add(attachedPic);
                        //System.debug('thumbnail' + attachedPic);
                    }
                }
                   
            if(pic.Miniature_Picture__c!=null){
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(pic.Miniature_Picture__c);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'image/jpeg');
            request.setCompressed(true);
            request.setTimeout(60000);
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                //responseValue = response.getBody(); 
                blob thumbnail = response.getBodyAsBlob();
                Attachment attachedThumbnail = new Attachment(); 
                attachedThumbnail.ParentId = pic.Id; 
                attachedThumbnail.Name = pic.Miniature_Picture__c.removeStartIgnoreCase('https://via.placeholder.com/150/')+'_150dpi'; 
                attachedThumbnail.contentType = 'image/jpeg';
                attachedThumbnail.Body = thumbnail;  
                 
                attachments.add(attachedThumbnail);
               // System.debug('thumbnail' + attachedThumbnail);
            }
        }
        
        } catch(Exception e){
        } 
        if(!attachments.isEmpty()){
            //System.debug('attachements to be inserted' + attachments);
            Database.SaveResult[] listOfInsertedAttachments = Database.insert(attachments, false);
           
           for(Database.SaveResult res: listOfInsertedAttachments){
                if(!res.isSuccess()){
                    insertNotSuccesful = true;
                }
                //System.debug('MJ2: ids to pass ' + picsIds);
            }
           
           
           if (picIds.size()>0 && !insertNotSuccesful){
               Id jobId = System.enqueueJob(new ImgSyncService.QueueablePicAttach(picIds));  
           }
        }
         
    }

    }  
    }      
    
   }