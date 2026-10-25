import { LightningElement, api, wire } from 'lwc';
import { openRecord } from 'c/ppOpenRecord';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { parseCard, errorText } from 'c/ppCardUtil';
import checkProposal from '@salesforce/apex/PPEventDraftController.check';
import createDraft from '@salesforce/apex/PPEventDraftController.createDraft';
import cancelDraft from '@salesforce/apex/PPEventDraftController.cancelDraft';

export default class PpEventPlannerCard extends NavigationMixin(LightningElement) {
    _val;
    _mob = null;

    goRecord(id) { this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } }); }
    get isMobile() { return !this._val && !!this._mob; }
    @api
    get value() { return this._val || this._mob; }
    set value(v) { this._val = v; }

    // The mobile app passes the card fields as c__<field> page-reference state params (lists as JSON strings).
    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        const state = pageRef && pageRef.state;
        if (!state || state.c__channel !== 'Mobile') return;
        const out = {};
        Object.keys(state).forEach((k) => {
            if (k.indexOf('c__') !== 0 || k === 'c__channel') return;
            let v = state[k];
            if (typeof v === 'string' && v !== '') { try { v = JSON.parse(v); } catch (e) { /* plain string */ } }
            out[k.substring(3)] = v;
        });
        if (Object.keys(out).length) this._mob = out;
    }
    edited = null;
    busy = false;
    created = null;
    cancelled = false;
    message = '';

    get card() { return this.edited || parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get hasProposal() { return !!(this.card && this.card.eventType); }
    get money() { return n => (n === null || n === undefined ? '-' : `$${Number(n).toLocaleString()}`); }
    get metrics() {
        const c = this.card;
        return [
            { key: 'm1', label: 'Total cost', value: this.money(c.totalCost), cls: 'pp-metric pp-tone-neutral' },
            { key: 'm2', label: 'Per attendee', value: this.money(c.costPerAttendee), cls: 'pp-metric pp-tone-neutral' },
            { key: 'm3', label: 'Budget left', value: this.money(c.budgetRemaining), cls: 'pp-metric pp-tone-neutral' }
        ];
    }
    get facts() {
        const c = this.card;
        return [
            { key: 'f1', label: 'Event', value: c.eventName },
            { key: 'f2', label: 'Type', value: `${c.eventType} (${c.mode || ''})` },
            { key: 'f3', label: 'Where', value: [c.city, c.locationType].filter(Boolean).join(' - ') },
            { key: 'f4', label: 'When', value: `${c.startDate} ${c.startTime || ''} for ${c.durationHours || 2}h` },
            { key: 'f5', label: 'Audience', value: c.audience },
            { key: 'f6', label: 'Products', value: (c.products || []).join(', ') || 'None' },
            { key: 'f7', label: 'Budget', value: c.budgetName || 'None' }
        ];
    }
    get expenses() {
        return ((this.card && this.card.expenses) || []).map((x, i) => ({ key: `e${i}`, label: x.label || x.expenseType, type: x.expenseType, amount: this.money(x.amount) }));
    }
    get checks() {
        return ((this.card && this.card.checks) || []).map((k, i) => ({ ...k, key: `k${i}`, cls: `ep-check ep-${k.level}`,
            icon: k.level === 'pass' ? 'utility:success' : (k.level === 'warn' ? 'utility:warning' : 'utility:error') }));
    }
    get options() {
        return ((this.card && this.card.options) || []).map((o, i) => ({ key: `o${i}`, eventType: o.eventType, why: o.why,
            meta: `${this.money(o.estCost)} - ${o.attendees || '?'} attendees` }));
    }
    get hasOptions() { return this.options.length > 0; }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    get showCreate() { return this.hasProposal && !this.created; }
    get createDisabled() { return this.busy || !this.card.canCreate; }
    get createLabel() { return this.busy ? 'Working...' : 'Create draft event'; }
    get createdText() { return this.cancelled ? `${this.created.eventName} was cancelled.` : `${this.created.eventName} is a Draft in your org.`; }

    async handleEdit(evt) {
        const f = evt.target.dataset.field;
        const next = { ...this.card, [f]: f === 'attendees' ? Number(evt.target.value) : evt.target.value };
        this.busy = true;
        try {
            const r = await checkProposal({ proposalJson: JSON.stringify(next) });
            this.edited = JSON.parse(r.proposalJson);
            this.message = '';
        } catch (e) {
            this.message = `Could not re-check: ${errorText(e)}`;
        }
        this.busy = false;
    }
    async handleCreate() {
        this.busy = true;
        try {
            this.created = await createDraft({ proposalJson: JSON.stringify(this.card) });
            this.message = this.created.message;
        } catch (e) {
            this.message = errorText(e);
        }
        this.busy = false;
    }
    handleOpen() {
        openRecord((id) => this.goRecord(id), this.created.eventId, this.isMobile);
    }
    async handleUndo() {
        this.busy = true;
        try {
            const r = await cancelDraft({ eventId: this.created.eventId });
            this.cancelled = true;
            this.message = r.message;
        } catch (e) {
            this.message = errorText(e);
        }
        this.busy = false;
    }
    get undoDisabled() { return this.busy || this.cancelled; }
}
