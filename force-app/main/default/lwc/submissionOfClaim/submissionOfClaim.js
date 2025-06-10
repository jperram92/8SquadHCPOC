import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitClaimToProvider from '@salesforce/apex/ClaimsProcessor.submitClaimFromLWC';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

// Import fields
import NAME_FIELD from '@salesforce/schema/Claim__c.Name';
import SERVICE_DATE_FIELD from '@salesforce/schema/Claim__c.ServiceDate__c';
import SERVICE_CODE_FIELD from '@salesforce/schema/Claim__c.ServiceCode__c';
import AMOUNT_FIELD from '@salesforce/schema/Claim__c.Amount__c';
import STATUS_FIELD from '@salesforce/schema/Claim__c.Status__c';
import PATIENT_NAME_FIELD from '@salesforce/schema/Claim__c.Patient__r.Name';

const FIELDS = [
    NAME_FIELD,
    SERVICE_DATE_FIELD,
    SERVICE_CODE_FIELD,
    AMOUNT_FIELD,
    STATUS_FIELD,
    PATIENT_NAME_FIELD
];

export default class SubmissionOfClaim extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;
    wiredClaimResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredClaim(result) {
        this.wiredClaimResult = result;
        if (result.data) {
            console.log('Claim data received:', JSON.stringify(result.data));
        }
        if (result.error) {
            console.error('Error loading claim:', JSON.stringify(result.error));
        }
    }

    get claim() {
        return this.wiredClaimResult?.data;
    }

    get claimNumber() {
        return getFieldValue(this.claim, NAME_FIELD);
    }

    get serviceDate() {
        return getFieldValue(this.claim, SERVICE_DATE_FIELD);
    }

    get serviceCode() {
        return getFieldValue(this.claim, SERVICE_CODE_FIELD);
    }

    get amount() {
        return getFieldValue(this.claim, AMOUNT_FIELD);
    }

    get status() {
        return getFieldValue(this.claim, STATUS_FIELD);
    }

    get patientName() {
        return getFieldValue(this.claim, PATIENT_NAME_FIELD);
    }

    get isDraft() {
        return getFieldValue(this.claim, STATUS_FIELD) === 'Draft';
    }

    get submitDisabled() {
        return !this.claim || !this.isDraft;
    }

    async handleSubmit() {
        try {
            this.isLoading = true;
            console.log('Submitting claim:', this.recordId);
            
            const result = await submitClaimToProvider({
                claimIds: [this.recordId]
            });
            
            console.log('Submission result:', result);
            
            if (result?.[0]?.status === 'Success') {
                this.showToast('Success', result[0].message, 'success');
                // Refresh page properly
                await this.refreshPage();
            } else {
                throw new Error(result?.[0]?.message || 'Error submitting claim');
            }
        } catch (error) {
            console.error('Submit error:', JSON.stringify(error));
            const msg = error.message || 'Failed to submit claim';
            this.showToast('Error', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async refreshPage() {
        // Refresh the record data
        await refreshApex(this.wiredClaimResult);
        
        // Navigate to the same page to refresh the view
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Claim__c',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async refreshView() {
        return new Promise((resolve) => {
            eval("$A.get('e.force:refreshView').fire();");
            setTimeout(resolve, 100);
        });
    }
}