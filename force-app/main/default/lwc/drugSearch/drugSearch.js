import { LightningElement, wire, track } from 'lwc';
import searchDrugs from '@salesforce/apex/RxNormService.searchDrugs';
import checkInteractions from '@salesforce/apex/RxNormService.checkInteractions';

export default class DrugSearch extends LightningElement {
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedDrugs = [];
    @track interactions = [];
    @track isLoading = false;
    @track error;

    columns = [
        { label: 'Drug Pair', fieldName: 'drugPair', type: 'text' },
        { label: 'Severity', fieldName: 'severity', type: 'text' },
        { label: 'Description', fieldName: 'description', type: 'text' }
    ];

    get formattedSearchResults() {
        return this.searchResults.map(drug => ({
            label: `${drug.name} (${drug.synonym || 'No synonym'})`,
            value: drug.rxcui
        }));
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 3) {
            this.performSearch();
        }
    }

    async performSearch() {
        this.isLoading = true;
        try {
            const results = await searchDrugs({ searchTerm: this.searchTerm });
            this.searchResults = results || [];
        } catch (error) {
            this.error = error.message;
        } finally {
            this.isLoading = false;
        }
    }

    handleDrugSelect(event) {
        const selectedRxcui = event.detail.value;
        const selectedDrug = this.searchResults.find(drug => drug.rxcui === selectedRxcui);
        
        if (selectedDrug && !this.selectedDrugs.some(drug => drug.rxcui === selectedDrug.rxcui)) {
            this.selectedDrugs = [...this.selectedDrugs, {
                label: selectedDrug.name,
                name: selectedDrug.name,
                rxcui: selectedDrug.rxcui
            }];
            this.checkDrugInteractions();
        }
    }

    handleDrugRemove(event) {
        const rxcuiToRemove = event.detail.item.rxcui;
        this.selectedDrugs = this.selectedDrugs.filter(drug => drug.rxcui !== rxcuiToRemove);
        if (this.selectedDrugs.length >= 2) {
            this.checkDrugInteractions();
        } else {
            this.interactions = [];
        }
    }

    async checkDrugInteractions() {
        if (this.selectedDrugs.length >= 2) {
            try {
                this.interactions = await checkInteractions({ 
                    rxcuiList: this.selectedDrugs.map(drug => drug.rxcui) 
                });
            } catch (error) {
                this.error = error.message;
            }
        }
    }
}
