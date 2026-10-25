import { LightningElement, api, wire } from 'lwc';
import { openRecord } from 'c/ppOpenRecord';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { parseCard, errorText } from 'c/ppCardUtil';
import addSpeaker from '@salesforce/apex/PPSpeakerController.addSpeaker';
import removeSpeaker from '@salesforce/apex/PPSpeakerController.removeSpeaker';

export default class PpSpeakerSearchCard extends NavigationMixin(LightningElement) {
    _val;
    _mob = null;

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
    busyId = null;
    addedByExpert = {};
    removed = {};
    message = '';

    get card() { return parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get candidates() {
        return ((this.card && this.card.candidates) || []).map((c, i) => {
            const added = this.addedByExpert[c.expertId];
            const gone = this.removed[c.expertId];
            const isIn = (c.added || !!added) && !gone;
            return {
                ...c, key: `c${i}`,
                fitCls: `sp-fit sp-${(c.fit || '').toLowerCase().replace(/\s+/g, '-')}`,
                meta: [c.specialty, c.city, c.tier ? `Tier ${c.tier}` : null, c.fee ? `$${Number(c.fee).toLocaleString()}` : null].filter(Boolean).join(' - '),
                checks: (c.checks || []).map((k, j) => ({ ...k, key: `k${i}${j}`, cls: `ep-check ep-${k.level}`,
                    icon: k.level === 'pass' ? 'utility:success' : (k.level === 'warn' ? 'utility:warning' : 'utility:error') })),
                isIn, showAdd: !isIn && c.canAdd, showUndo: !!added && !gone,
                busy: this.busyId === c.expertId
            };
        });
    }
    get hasCandidates() { return this.candidates.length > 0; }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    async handleAdd(evt) {
        const id = evt.target.dataset.id;
        this.busyId = id;
        try {
            const r = await addSpeaker({ eventId: this.card.eventId, expertId: id });
            this.addedByExpert = { ...this.addedByExpert, [id]: r.eventId };
            this.removed = { ...this.removed, [id]: false };
            this.message = r.message;
        } catch (e) {
            this.message = errorText(e);
        }
        this.busyId = null;
    }
    async handleUndo(evt) {
        const id = evt.target.dataset.id;
        this.busyId = id;
        try {
            const r = await removeSpeaker({ participantId: this.addedByExpert[id] });
            this.removed = { ...this.removed, [id]: true };
            this.message = r.message;
        } catch (e) {
            this.message = errorText(e);
        }
        this.busyId = null;
    }
    handleOpen() {
        openRecord((id) => this.goRecord(id), this.card.eventId, this.isMobile);
    }
    handleOpenRecord(evt) {
        evt.preventDefault();
        openRecord((id) => this.goRecord(id), evt.currentTarget.dataset.id, this.isMobile);
    }
    get canOpen() { return !!(this.card && this.card.eventId); }
}
