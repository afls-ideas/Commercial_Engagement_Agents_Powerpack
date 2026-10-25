import { LightningElement, api, wire } from 'lwc';
import { openRecord } from 'c/ppOpenRecord';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

const ORDER = {
    speakers: ['speakers', 'attendees', 'colleagues', 'facts'],
    attendees: ['attendees', 'speakers', 'colleagues', 'facts'],
    history: ['attendees', 'speakers', 'colleagues', 'facts'],
    budget: ['facts', 'speakers', 'attendees', 'colleagues'],
    overview: ['facts', 'speakers', 'attendees', 'colleagues']
};
const TITLES = { speakers: 'Speakers', attendees: 'Attendees', colleagues: 'Colleagues', facts: 'Event details' };

export default class PpEventBriefCard extends NavigationMixin(LightningElement) {
    _val;
    _mob = null;
    openMap = {};

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

    get card() {
        const v = this.value;
        if (!v) return null;
        if (typeof v === 'string') { try { return JSON.parse(v); } catch (e) { return null; } }
        return v;
    }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get metrics() {
        return ((this.card && this.card.metrics) || []).map((m, i) => ({ ...m, key: `m${i}`, cls: `pp-metric pp-tone-${m.tone || 'neutral'}` }));
    }
    get hasMetrics() { return this.metrics.length > 0; }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    get blocks() {
        const c = this.card || {};
        const focus = ORDER[c.focus] ? c.focus : 'overview';
        const out = [];
        ORDER[focus].forEach((k) => {
            if (k === 'facts') {
                const rows = (c.facts || []).map((f, i) => ({ key: `f${i}`, label: f.label, value: f.value, cls: `ev-fact-v ev-${f.tone || 'neutral'}` }));
                if (rows.length) out.push({ key: k, title: TITLES[k], isFacts: true, isPeople: false, rows });
            } else {
                const people = this.people(c[k] || [], k);
                if (people.length) {
                    const more = k === 'attendees' && c.moreAttendees ? `${c.moreAttendees} more attendees not shown` : '';
                    out.push({ key: k, title: `${TITLES[k]} (${people.length + (c.moreAttendees && k === 'attendees' ? c.moreAttendees : 0)})`, isFacts: false, isPeople: true, people, more });
                }
            }
        });
        return out;
    }
    people(list, group) {
        return list.map((p, i) => {
            const key = `${group}${i}`;
            const history = (p.past || []);
            const open = this.openMap[key] !== undefined ? this.openMap[key] : (p.highlight || (this.card.focus === 'history' && group === 'attendees' && history.length > 0 && i < 10) || this.card.focus === 'speakers' && group === 'speakers');
            const chips = [];
            if (p.response) chips.push({ key: 'r', text: p.response, cls: `ev-chip ev-chip-${(p.response || '').toLowerCase().replace(/\s+/g, '-')}` });
            if (p.attendance) chips.push({ key: 'a', text: p.attendance, cls: `ev-chip ev-chip-${(p.attendance || '').toLowerCase().replace(/\s+/g, '-')}` });
            const meta = [p.kind === 'Person' ? null : p.role, p.specialty, p.tier ? `Tier ${p.tier}` : null, p.fee ? `$${Number(p.fee).toLocaleString()}` : null].filter(Boolean).join(' - ');
            return {
                ...p, key, meta, chips, open, hasHistory: history.length > 0,
                toggleLabel: `${open ? 'Hide' : 'Show'} earlier events (${history.length})`,
                flagCls: `ev-flag ev-${p.tone || 'neutral'}`,
                notes: (p.notes || []).map((n, j) => ({ key: `n${j}`, text: n })),
                hasNotes: (p.notes || []).length > 0,
                past: history.map((h, j) => ({
                    ...h, key: `h${j}`,
                    line: [h.eventDate, h.status].filter(Boolean).join(' - '),
                    outcome: h.attendance || h.response || 'No response recorded',
                    outCls: `ev-chip ev-chip-${(h.attendance || h.response || 'none').toLowerCase().replace(/\s+/g, '-')}`
                }))
            };
        });
    }
    handleToggle(evt) {
        const key = evt.target.dataset.key;
        const cur = evt.target.dataset.open === 'true';
        this.openMap = { ...this.openMap, [key]: !cur };
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
