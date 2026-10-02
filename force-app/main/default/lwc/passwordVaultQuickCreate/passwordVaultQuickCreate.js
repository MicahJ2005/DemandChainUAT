import SHORT_NAME_FIELD from "@salesforce/schema/Account.Account_Name_Short__c";
import VAULT_ID_FIELD from "@salesforce/schema/Account.CredentialVaultId__c";
import NAME_FIELD from "@salesforce/schema/Account.Name";
import { CloseActionScreenEvent } from "lightning/actions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord } from "lightning/uiRecordApi";
import { LightningElement, api, wire } from "lwc";
import createVaultAsync from "@salesforce/apex/PasswordVaultService.createVaultAsync";

const ACCOUNT_FIELDS = [NAME_FIELD, SHORT_NAME_FIELD, VAULT_ID_FIELD];

export default class PasswordVaultQuickCreate extends LightningElement {
    loaded = false;
    _recordId;
    vaultNameInput = "";

    @api set recordId(value) {
        this._recordId = value;
    }
    get recordId() {
        return this._recordId;
    }

    @wire(getRecord, { recordId: "$recordId", fields: ACCOUNT_FIELDS })
    account({ error, data }) {
        if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error loading account",
                    message: error.message,
                    variant: "error"
                })
            );
        } else if (data) {
            this.account = data;
            if (this.hasVaultId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Not needed",
                        message: `${this.account.fields.Name.value} already has a vault.`,
                        variant: "success"
                    })
                );
                this.handleCancel();
                return;
            }
            this.loaded = true;
        }
    }

    get hasVaultId() {
        if (!this.account?.fields?.CredentialVaultId__c?.value) {
            return false;
        }
        return this.account.fields.CredentialVaultId__c.value !== null;
    }

    get notHasVaultId() {
        return !this.hasVaultId;
    }

    get defaultVaultName() {
        if (!this.account?.fields) {
            return "";
        }
        let accountNameShort = this.account.fields?.Account_Name_Short__c?.value;
        return accountNameShort ? accountNameShort : this.account.fields.Name.value;
    }

    handleNameChange(event) {
        this.vaultNameInput = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCreate() {
        let input = this.template.querySelector("lightning-input");
        if (!input.validity.valid) {
            return;
        }

        createVaultAsync({ accountId: this.recordId, vaultName: this.vaultNameInput });
        this.vaultNameInput = this.dispatchEvent(
            new ShowToastEvent({
                title: "Processing",
                message: `The vault is being created in the background.\nThis may take up to two minutes.`,
                variant: "success"
            })
        );
        this.handleCancel();
    }
}