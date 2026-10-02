// File: projectList.js
import { LightningElement, wire, api } from 'lwc';
import getProjects from '@salesforce/apex/ProjectController.getProjects';

export default class ProjectList extends LightningElement {
    @api recordId; // This is set by the framework when on a record page
    projects;
    error;

    @wire(getProjects)
    wiredProjects({ error, data }) {
        if (data) {
            this.projects = data;
        } else if (error) {
            this.error = error;
        }
    }
}