public with sharing class ClaimsProcessor {
    @AuraEnabled
    public static List<ClaimResult> submitClaimFromLWC(List<Id> claimIds) {
        List<ClaimResult> results = new List<ClaimResult>();
        
        try {
            // Query claims first
            List<Claim__c> claims = [
                SELECT Id, Name, ServiceDate__c, ServiceCode__c, 
                       Amount__c, Status__c, Patient__r.Name
                FROM Claim__c 
                WHERE Id IN :claimIds];
            
            // Make callout before starting transaction
            Map<Id, ClaimResponse> responses = new Map<Id, ClaimResponse>();
            for(Claim__c claim : claims) {
                if(claim.Status__c != 'Draft') {
                    throw new ClaimsException('Claim must be in Draft status');
                }
                responses.put(claim.Id, ClaimsIntegrationService.submitClaimToPayer(claim));
            }
            
            // Start transaction after callouts
            Savepoint sp = Database.setSavepoint();
            try {
                for(Claim__c claim : claims) {
                    ClaimResponse response = responses.get(claim.Id);
                    claim.Status__c = response.status == 'ACCEPTED' ? 'Submitted' : response.status;
                }
                
                update claims;
                
                // Add results
                for(Claim__c claim : claims) {
                    ClaimResponse response = responses.get(claim.Id);
                    results.add(new ClaimResult(
                        claim.Id,
                        'Success',
                        response.message
                    ));
                }
            } catch(Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch(Exception e) {
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