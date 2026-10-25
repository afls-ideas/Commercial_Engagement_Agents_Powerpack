import { LightningElement, api } from 'lwc';

export default class PpCaseDayCard extends LightningElement {
    @api value;

    get card() {
        if (!this.value) return null;
        if (typeof this.value === 'string') {
            try { return JSON.parse(this.value); } catch (e) { return null; }
        }
        return this.value;
    }
}
