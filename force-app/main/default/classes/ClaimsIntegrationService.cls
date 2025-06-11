/**
 * @description       : 
 * @author            : jamesperram@gmail.com
 * @group             : 
 * @last modified on  : 06-11-2025
 * @last modified by  : jamesperram@gmail.com
**/
public with sharing class ClaimsIntegrationService {
    private static final String ENDPOINT = 'callout:ClaimsAPI';
    
    public static void testConnection() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://postman-echo.com/get');
            req.setMethod('GET');
            req.setTimeout(120000);
            
            System.debug(LoggingLevel.ERROR, '>>> Testing connection to: ' + req.getEndpoint());
            System.debug(LoggingLevel.ERROR, '>>> Request method: ' + req.getMethod());
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug(LoggingLevel.ERROR, '>>> Response Status: ' + res.getStatusCode());
            System.debug(LoggingLevel.ERROR, '>>> Response Status Message: ' + res.getStatus());
            System.debug(LoggingLevel.ERROR, '>>> Response Body: ' + res.getBody());
            
        } catch(Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Connection Error Type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, '>>> Connection Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack Trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    public static ClaimResponse submitClaimToPayer(Claim__c claim) {
        try {
            // Prepare request body
            Map<String, Object> requestBody = new Map<String, Object>{
                'claimNumber' => claim.Name,
                'serviceDate' => claim.ServiceDate__c.format(),
                'serviceCode' => claim.ServiceCode__c,
                'amount' => claim.Amount__c,
                'patientName' => claim.Patient__r.Name
            };
            
            // Setup request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(requestBody));
            
            System.debug(LoggingLevel.ERROR, '>>> Making callout to: ' + req.getEndpoint());
            System.debug(LoggingLevel.ERROR, '>>> Request body: ' + req.getBody());
            
            // Make callout
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug(LoggingLevel.ERROR, '>>> Response Status: ' + res.getStatusCode());
            System.debug(LoggingLevel.ERROR, '>>> Response Status Message: ' + res.getStatus());
            System.debug(LoggingLevel.ERROR, '>>> Response Body: ' + res.getBody());
            
            // Handle response
            if(res.getStatusCode() == 200) {
                String responseBody = res.getBody().trim();
                System.debug(LoggingLevel.ERROR, '>>> Raw response body: ' + responseBody);
                
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                System.debug(LoggingLevel.ERROR, '>>> Parsed response map: ' + responseMap);
                
                // Get values directly from response
                String status = String.valueOf(responseMap.get('status'));
                String message = String.valueOf(responseMap.get('message'));
                
                // Make External ID unique by adding timestamp
                String timestamp = String.valueOf(System.currentTimeMillis());
                String externalId = String.valueOf(responseMap.get('claimId')) + '-' + timestamp;
                
                System.debug(LoggingLevel.ERROR, '>>> Generated unique External ID: ' + externalId);
                
                // Update claim with response details
                claim.Status__c = 'Paid';
                claim.External_ID__c = externalId; // Will now be something like: EXT-CLM-0005-1749599710527
                claim.External_Status__c = status;
                
                if(responseMap.containsKey('paymentDetails')) {
                    Map<String, Object> paymentDetails = (Map<String, Object>)responseMap.get('paymentDetails');
                    claim.Payment_Transaction_ID__c = 'TXN-' + String.valueOf(System.currentTimeMillis());
                    
                    // Check for medication interactions if this is a pharmacy claim
                    if(claim.Claims_Type__c == 'Pharmacy') {
                        List<String> rxcuis = getMedicationRxCUIs(claim.Patient__c);
                        if(!rxcuis.isEmpty()) {
                            List<RxNormService.InteractionPair> interactions = 
                                RxNormService.checkInteractions(rxcuis);
                            logMedicationInteractions(interactions, claim.Patient__c);
                        }
                    }
                }
                claim.Payment_Date__c = DateTime.now();
                update claim;
                
                return new ClaimResponse(
                    claim.Id,
                    'Paid',
                    message,
                    externalId
                );
            } else {
                throw new ClaimsException('HTTP Error: ' + res.getStatusCode() + ' - ' + res.getStatus());
            }
        } catch(Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Callout Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '>>> Stack Trace: ' + e.getStackTraceString());
            throw new ClaimsException('Failed to submit claim: ' + e.getMessage());
        }
    }

    private static List<String> getMedicationRxCUIs(Id patientId) {
        List<String> rxcuis = new List<String>();
        // Query for patient's medications and collect RxCUIs
        // Implementation depends on your data model
        return rxcuis;
    }

    private static void logMedicationInteractions(
        List<RxNormService.InteractionPair> interactions, 
        Id patientId
    ) {
        List<Medication_Interaction__c> interactionsToInsert = new List<Medication_Interaction__c>();
        for(RxNormService.InteractionPair pair : interactions) {
            interactionsToInsert.add(new Medication_Interaction__c(
                Patient__c = patientId,
                Description__c = pair.description,
                Severity__c = pair.severity,
                Drug_Pair__c = pair.drugPair
            ));
        }
        if(!interactionsToInsert.isEmpty()) {
            insert interactionsToInsert;
        }
    }
}