/**
 * @description       : 
 * @author            : jamesperram@gmail.com
 * @group             : 
 * @last modified on  : 06-10-2025
 * @last modified by  : jamesperram@gmail.com
**/
    public class ClaimDataFactory {
        public static void createSampleClaims() {
            // Create a test patient account without record type
            Account patient = new Account(
                Name = 'John Doe'
            );
            insert patient;
            
            // Create sample claims
            List<Claim__c> claims = new List<Claim__c>();
            for(Integer i = 0; i < 5; i++) {
                claims.add(new Claim__c(
                    Patient__c = patient.Id,
                    ServiceDate__c = Date.today(),
                    ServiceCode__c = '04_210_0125_6_1', // Home Care Level 1
                    Amount__c = 150.00,
                    Status__c = 'Draft'
                ));
            }
            insert claims;
            
            // Add debug output
            System.debug('Created patient account: ' + patient.Id);
            System.debug('Created ' + claims.size() + ' sample claims');
            for(Claim__c claim : claims) {
                System.debug('Claim: ' + claim.Id);
            }
        }
    }
