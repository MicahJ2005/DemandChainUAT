import { LightningElement, track } from 'lwc';
import submitCaseToOtherOrg from '@salesforce/apex/RemoteCaseSubmitService.sendCaseToTargetOrg';

export default class CaseForm extends LightningElement {
    @track subject = '';
    @track description = '';
    @track email = '';
    @track showModal = true;
    @track showSuccess = false;
    @track caseId = '';
    @track errorMsg = '';

    handleOpenModal() {
        this.resetForm();
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleSubmit() {
        this.errorMsg = '';
        this.showSuccess = false;

        submitCaseToOtherOrg({
            subject: this.subject,
            description: this.description,
            contactEmail: this.email
        })
            .then(result => {
                console.log(result);
                // Assume result is a Case ID string
                this.caseId = result;
                this.showSuccess = true;
                // this.handleCloseModal()
            })
            .catch(error => {
                this.errorMsg = error?.body?.message || 'Unknown error occurred.';
                this.showSuccess = false;
            });
    }

    handleInputChange(event) {
        this[event.target.name] = event.target.value;
    }

    resetForm() {
        this.subject = '';
        this.description = '';
        this.email = '';
        this.caseId = '';
        this.errorMsg = '';
        this.showSuccess = false;
    }
}