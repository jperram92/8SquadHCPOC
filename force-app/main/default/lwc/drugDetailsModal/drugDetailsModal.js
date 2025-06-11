import { LightningElement, api } from 'lwc';

export default class DrugDetailsModal extends LightningElement {
    @api drugDetails;
    showModal = false;

    get hasWarnings() {
        return this.drugDetails?.warnings && this.drugDetails.warnings.length > 0;
    }

    get genericLabel() {
        return this.drugDetails?.isGeneric ? 'Generic Drug' : 'Brand Name Drug';
    }

    get genericClass() {
        return `slds-theme_${this.drugDetails?.isGeneric ? 'success' : 'info'}`;
    }

    get strengthDisplay() {
        return this.drugDetails?.strength || 'Multiple Strengths Available';
    }

    get scheduleDisplay() {
        return `Schedule ${this.drugDetails?.schedule || 'Not Controlled'}`;
    }

    @api
    show(details) {
        this.drugDetails = details;
        this.showModal = true;
    }

    handleClose() {
        this.showModal = false;
    }
}
