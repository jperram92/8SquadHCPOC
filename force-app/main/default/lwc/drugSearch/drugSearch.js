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

    searchColumns = [
        { 
            label: 'Name', 
            fieldName: 'displayName', 
            type: 'text',
            sortable: true,
            wrapText: true
        },
        { 
            label: 'Strength', 
            fieldName: 'strength', 
            type: 'text',
            sortable: true,
            wrapText: false,
            cellAttributes: { 
                class: { fieldName: 'strengthClass' }
            }
        },
        { 
            label: 'Form', 
            fieldName: 'dosageForm', 
            type: 'text',
            sortable: true
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Select', name: 'select' },
                    { label: 'View Details', name: 'view_details' }
                ]
            }
        }
    ];

    interactionColumns = [
        { label: 'Drug Pair', fieldName: 'drugPair', type: 'text' },
        { label: 'Severity', fieldName: 'severity', type: 'text',
            cellAttributes: {
                class: { fieldName: 'severityClass' }
            }
        },
        { label: 'Description', fieldName: 'description', type: 'text', wrapText: true }
    ];

    get formattedSearchResults() {
        return this.searchResults.map(drug => {
            // Extract strength number and unit from name if not provided
            let strengthInfo = this.extractStrengthFromName(drug.name);
            
            return {
                ...drug,
                displayName: drug.name,
                strength: drug.strength || strengthInfo.strength || 'Various Strengths',
                strengthClass: drug.strength || strengthInfo.strength ? 'slds-text-color_default' : 'slds-text-color_weak',
                dosageForm: drug.dosageForm || this.extractFormFromName(drug.name) || 'Multiple Forms',
                drugClass: drug.drugClass || 'Classification Pending'
            };
        });
    }

    extractStrengthFromName(name) {
        // Common patterns: "10 MG", "100MG", "10 MG/ML", etc.
        const strengthPattern = /(\d+(?:\.\d+)?)\s*(?:MG|MCG|G|ML|%)/i;
        const match = name.match(strengthPattern);
        if (match) {
            return {
                strength: match[0].toUpperCase(),
                nameWithoutStrength: name.replace(match[0], '').trim()
            };
        }
        return { strength: null, nameWithoutStrength: name };
    }

    extractFormFromName(name) {
        const forms = ['Tablet', 'Capsule', 'Solution', 'Suspension', 'Injection', 'Cream', 'Ointment'];
        for (let form of forms) {
            if (name.toLowerCase().includes(form.toLowerCase())) {
                return form;
            }
        }
        return null;
    }

    get formattedInteractions() {
        return this.interactions.map(interaction => ({
            ...interaction,
            severityClass: this.getSeverityClass(interaction.severity)
        }));
    }

    getSeverityClass(severity) {
        switch(severity.toLowerCase()) {
            case 'high': return 'slds-text-color_error';
            case 'moderate': return 'slds-text-color_warning';
            default: return 'slds-text-color_success';
        }
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

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        switch (action.name) {
            case 'select':
                this.handleDrugSelect({ detail: { value: row.rxcui } });
                break;
            case 'view_details':
                const modalComponent = this.template.querySelector('c-drug-details-modal');
                if (modalComponent) {
                    // Pass all available drug information to the modal
                    const drugInfo = {
                        ...row,
                        name: row.displayName,
                        rxcui: row.rxcui,
                        strength: row.strength,
                        dosageForm: row.dosageForm,
                        drugClass: row.drugClass,
                        synonym: row.synonym,
                        brandNames: row.brandNames,
                        warnings: row.warnings,
                        route: row.route,
                        ndc: row.ndc,
                        schedule: row.schedule,
                        marketingStatus: row.marketingStatus,
                        labeler: row.labeler
                    };
                    modalComponent.show(drugInfo);
                }
                break;
        }
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.formattedSearchResults];

        cloneData.sort((a, b) => {
            return sortDirection === 'asc' ? 
                (a[sortedBy] > b[sortedBy] ? 1 : -1) : 
                (b[sortedBy] > a[sortedBy] ? 1 : -1);
        });

        this.searchResults = cloneData;
        this.sortBy = sortedBy;
        this.sortDirection = sortDirection;
    }
}
