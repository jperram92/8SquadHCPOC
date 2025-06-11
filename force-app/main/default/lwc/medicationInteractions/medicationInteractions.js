import { LightningElement, api, wire } from 'lwc';
import checkInteractions from '@salesforce/apex/RxNormService.checkInteractions';

export default class MedicationInteractions extends LightningElement {
    @api recordId;
    interactions = [];
    error;
    isLoading = false;

    async handleCheckInteractions() {
        this.isLoading = true;
        try {
            // Using test RxCUIs for demo - replace with actual query
            const rxcuis = ['207106', '152923', '656659'];
            this.interactions = await checkInteractions({ rxcuiList: rxcuis });
        } catch (error) {
            this.error = error.message;
        } finally {
            this.isLoading = false;
        }
    }
}
