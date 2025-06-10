// Execute this in Developer Console > Debug > Open Execute Anonymous Window
ClaimDataFactory.createSampleClaims();

// Query and verify the created records
List<Claim__c> claims = [
    SELECT Id, Name, Patient__c, ServiceDate__c, 
           ServiceCode__c, Amount__c, Status__c 
    FROM Claim__c 
    ORDER BY CreatedDate DESC 
    LIMIT 5
];

System.debug('Created Claims: ' + claims);
