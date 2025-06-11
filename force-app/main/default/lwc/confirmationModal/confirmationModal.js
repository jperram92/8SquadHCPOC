import { LightningElement, api } from 'lwc';

export default class ConfirmationModal extends LightningElement {
    @api title;
    @api message;
    @api drugDetails;
    showModal = false;

    @api
    show(title, message, drugDetails) {
        this.title = title;
        this.message = message;
        this.drugDetails = drugDetails;
        this.showModal = true;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
        this.showModal = false;
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
        this.showModal = false;
    }
}
