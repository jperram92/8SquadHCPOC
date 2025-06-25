import { LightningElement, track, wire } from 'lwc';
import { subscribe, onError, MessageContext } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CaseAlertListener extends LightningElement {
    @track channelName = '/event/Case_Alert__e';
    subscription = {};

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.registerErrorListener();
        this.subscribeToEvent();
    }

    subscribeToEvent() {
        subscribe(this.channelName, -1, (event) => {
            const payload = event.data.payload;
            this.showNotification(payload);
        }).then(response => {
            this.subscription = response;
            console.log('✅ Subscribed to Case Alert Platform Event:', JSON.stringify(response));
        });
    }

    registerErrorListener() {
        onError(error => {
            console.error('❌ Platform Event Error:', JSON.stringify(error));
        });
    }

    showNotification(payload) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: '🚨 High Priority Case Alert',
                message: `Case #${payload.Case_Number__c}: ${payload.Subject__c}`,
                variant: 'warning',
                mode: 'sticky'
            })
        );
    }
}