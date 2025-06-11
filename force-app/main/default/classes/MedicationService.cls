public with sharing class MedicationService {
    @AuraEnabled
    public static Medication__c createMedication(String rxcui, String name, String strength, String dosageForm, String patientId) {
        // Validate required fields
        if (String.isBlank(patientId)) {
            throw new AuraHandledException('Patient ID is required');
        }
        if (String.isBlank(name)) {
            throw new AuraHandledException('Medication name is required');
        }
        
        try {
            Medication__c med = new Medication__c(
                Name = name,
                RxCUI__c = rxcui,
                Strength__c = strength,
                Dosage_Form__c = dosageForm,
                Patient__c = patientId,
                Status__c = 'Active'
            );
            
            insert med;
            return med;
        } catch(Exception e) {
            throw new AuraHandledException('Error creating medication: ' + e.getMessage());
        }
    }
}
