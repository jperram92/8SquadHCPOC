import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitClaimToProvider from '@salesforce/apex/ClaimsProcessor.submitClaimFromLWC';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Claim__c.Name',
    'Claim__c.ServiceDate__c',
    'Claim__c.ServiceCode__c',
    'Claim__c.Amount__c',
    'Claim__c.Status__c'
];

export default class SubmitClaim extends LightningElement {
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        console.log('Record ID set:', value);
    }
    _recordId;
    @track isLoading = false;
    @track claim;
    
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredClaim({ error, data }) {
        if (data) {
            this.claim = data.fields;
            console.log('Loaded claim data:', this.claim);
        } else if (error) {
            console.error('Error loading claim:', error);
            this.showError('Error loading claim details');
        }
    }

    get isValid() {
        return this.claim && 
               this.claim.ServiceDate__c.value &&
               this.claim.ServiceCode__c.value &&
               this.claim.Amount__c.value &&
               this.claim.Status__c.value === 'Draft';
    }

    get isNotValid() {
        return !this.claim || 
               !this.claim.ServiceDate__c.value ||
               !this.claim.ServiceCode__c.value ||
               !this.claim.Amount__c.value ||
               this.claim.Status__c.value !== 'Draft';
    }

    renderedCallback() {
        console.log('Component rendered with recordId:', this.recordId);
    }

    async handleSubmit() {
        if (!this._recordId || !this.claim) {
            console.error('Cannot submit - No claim data available');
            this.showError('Unable to submit claim - Missing data');
            return;
        }

        try {
            this.isLoading = true;
            console.log('Submitting claim:', this._recordId);
            
            const result = await submitClaimToProvider({
                claimIds: [this._recordId]
            });
            
            console.log('Submission result:', result);

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `Claim ${this.claim.Name.value} submitted successfully`,
                variant: 'success'
            }));
            
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            console.error('Error submitting claim:', error);
            this.showError(error.body?.message || 'Error submitting claim');
        } finally {
            this.isLoading = false;
        }
    }

    connectedCallback() {
        console.log('Component initialized with ID:', this._recordId);
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        }));
    }
}