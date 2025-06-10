public with sharing class ClaimsProcessor {
    @AuraEnabled
    public static List<ClaimResult> submitClaimFromLWC(List<Id> claimIds) {
        System.debug('Received claim IDs for processing: ' + claimIds);
        List<ClaimResult> results = new List<ClaimResult>();
        
        // Start transaction
        Savepoint sp = Database.setSavepoint();
        
        try {
            List<Claim__c> claims = [
                SELECT Id, Name, ServiceDate__c, ServiceCode__c, 
                       Amount__c, Status__c, Patient__r.Name
                FROM Claim__c 
                WHERE Id IN :claimIds
                FOR UPDATE
            ];
            
            // Process claims
            for(Claim__c claim : claims) {
                try {
                    if(claim.Status__c != 'Draft') {
                        throw new ClaimsException('Claim must be in Draft status');
                    }
                    
                    // Call integration service
                    ClaimResponse response = ClaimsIntegrationService.submitClaimToPayer(claim);
                    
                    // Update status on success
                    claim.Status__c = response.status;
                    update claim;
                    
                    results.add(new ClaimResult(
                        claim.Id,
                        'Success',
                        'Claim ' + claim.Name + ' submitted successfully'
                    ));
                } catch(Exception e) {
                    Database.rollback(sp);
                    results.add(new ClaimResult(claim.Id, 'Error', e.getMessage()));
                    return results;
                }
            }
        } catch(Exception e) {
            Database.rollback(sp);
            results.add(new ClaimResult(claimIds[0], 'Error', e.getMessage()));
        }
        
        return results;
    }
    
    public class ClaimResult {
        @AuraEnabled public Id claimId { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String message { get; set; }
        
        public ClaimResult(Id claimId, String status, String message) {
            this.claimId = claimId;
            this.status = status;
            this.message = message;
        }
    }
}