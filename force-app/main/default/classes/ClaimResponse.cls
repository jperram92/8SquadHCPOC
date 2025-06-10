public class ClaimResponse {
    @AuraEnabled public Id claimId { get; set; }
    @AuraEnabled public String status { get; set; }
    @AuraEnabled public String message { get; set; }
    
    public ClaimResponse(Id claimId, String status, String message) {
        this.claimId = claimId;
        this.status = status;
        this.message = message;
    }
}