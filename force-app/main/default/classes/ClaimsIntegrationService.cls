public with sharing class ClaimsIntegrationService {
    
    private static final String ENDPOINT = 'callout:ClaimsAPI/claims';
    
    public static ClaimResponse submitClaimToPayer(Claim__c claim) {
        System.debug('Preparing outbound message for claim: ' + claim.Name);
        
        // Prepare request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'claimNumber' => claim.Name,
            'serviceDate' => claim.ServiceDate__c,
            'serviceCode' => claim.ServiceCode__c,
            'amount' => claim.Amount__c,
            'patientName' => claim.Patient__r.Name
        };
        
        // Log outbound attempt
        Integration_Log__c log = new Integration_Log__c(
            Claim__c = claim.Id,
            Direction__c = 'Outbound',
            Status__c = 'Pending',
            Request_Body__c = JSON.serialize(requestBody)
        );
        insert log;
        
        try {
            // Make callout
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(ENDPOINT);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(requestBody));
            
            // Get response
            HttpResponse response = http.send(request);
            System.debug('Received response: ' + response.getBody());
            
            // Update log
            log.Response_Body__c = response.getBody();
            log.Status__c = 'Completed';
            update log;
            
            if(response.getStatusCode() == 200) {
                return new ClaimResponse(
                    claim.Id, 
                    'Submitted',
                    'Claim submitted successfully'
                );
            } else {
                throw new ClaimsException('Failed to submit claim: ' + response.getBody());
            }
        } catch(Exception e) {
            // Update log with error
            log.Status__c = 'Error';
            log.Response_Body__c = e.getMessage();
            update log;
            throw e;
        }
    }
}