import { LightningElement, api, wire } from 'lwc';
import { openRecord } from 'c/ppOpenRecord';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { parseCard, errorText, runAction } from 'c/ppCardUtil';

const W = 340, H = 290, ROW_Y = { executive: 36, 'decision maker': 108, influencer: 184, user: 256 };

export default class PpCoverageMapCard extends NavigationMixin(LightningElement) {
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
    selectedIdx;
    done = {};
    message = '';

    get card() { return parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get viewBox() { return `0 0 ${W} ${H}`; }
    get metrics() {
        return ((this.card && this.card.metrics) || []).map((m, i) => ({ ...m, key: `m${i}`, cls: `pp-metric pp-tone-${m.tone || 'neutral'}` }));
    }
    get layout() {
        const nodes = (this.card && this.card.nodes) || [];
        const rows = {};
        nodes.forEach((n, i) => {
            const k = ROW_Y[(n.tier || '').toLowerCase()] ? (n.tier || '').toLowerCase() : 'user';
            (rows[k] = rows[k] || []).push(i);
        });
        const pos = {};
        Object.keys(rows).forEach(k => {
            const list = rows[k];
            list.forEach((idx, j) => { pos[idx] = { x: ((j + 1) * W) / (list.length + 1), y: ROW_Y[k] }; });
        });
        return pos;
    }
    get currentIdx() {
        const nodes = (this.card && this.card.nodes) || [];
        if (this.selectedIdx !== undefined && nodes[this.selectedIdx]) return this.selectedIdx;
        const order = { gap: 0, cooling: 1, covered: 2 };
        const rank = { executive: 0, 'decision maker': 1, influencer: 2, user: 3 };
        let best = 0;
        nodes.forEach((n, i) => {
            const a = [order[(n.status || '').toLowerCase()] ?? 2, rank[(n.tier || '').toLowerCase()] ?? 3];
            const b = [order[(nodes[best].status || '').toLowerCase()] ?? 2, rank[(nodes[best].tier || '').toLowerCase()] ?? 3];
            if (a[0] < b[0] || (a[0] === b[0] && a[1] < b[1])) best = i;
        });
        return best;
    }
    get nodes() {
        const raw = (this.card && this.card.nodes) || [];
        const pos = this.layout;
        return raw.map((n, i) => {
            const st = (n.status || 'covered').toLowerCase();
            const sel = i === this.currentIdx;
            const strength = Math.max(0, Math.min(100, Number(n.strength) || 0));
            const parts = (n.name || '?').replace(/,.*$/, '').replace(/^(Dr\.|Prof\.)\s*/i, '').split(/\s+/);
            return {
                ...n, idx: i, key: `n${i}`, sel,
                transform: `translate(${pos[i].x} ${pos[i].y})`,
                ringW: 2 + (strength / 100) * 6,
                gCls: `cv-node cv-${st}${sel ? ' cv-sel' : ''}`,
                chipCls: `pp-chip cv-chip-${st}`,
                rowCls: `cm-row${sel ? ' cm-row-selected' : ''}`,
                initials: parts.map(w => w[0]).slice(0, 2).join('').toUpperCase(),
                short: parts[parts.length - 1],
                aria: `${n.name}, ${n.status}, strength ${strength}`,
                since: n.daysSince === null || n.daysSince === undefined ? 'never contacted' : `${n.daysSince} days ago`
            };
        });
    }
    get edges() {
        const nodes = (this.card && this.card.nodes) || [];
        const pos = this.layout;
        const byName = {};
        nodes.forEach((n, i) => { byName[(n.name || '').toLowerCase()] = i; });
        const out = [];
        nodes.forEach((n, i) => {
            const j = byName[(n.reportsTo || '').toLowerCase()];
            if (j !== undefined && j !== i) out.push({ key: `e${i}`, x1: pos[j].x, y1: pos[j].y, x2: pos[i].x, y2: pos[i].y });
        });
        return out;
    }
    get hasNodes() { return this.nodes.length > 0; }
    get selected() {
        const n = this.nodes[this.currentIdx];
        return n ? { ...n,
            actionLabel: n.action ? (this.done[`n${n.idx}`] ? `${n.action.label} \u2713` : n.action.label) : '',
            actionDisabled: !!this.done[`n${n.idx}`],
            actionCls: n.action && n.action.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn' } : null;
    }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    get actions() {
        return ((this.card && this.card.actions) || []).map((a, i) => ({
            ...a, key: `x${i}`, label: this.done[`x${i}`] ? `${a.label} \u2713` : a.label,
            disabled: !!this.done[`x${i}`], cls: a.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'
        }));
    }
    get hasActions() { return this.actions.length > 0; }

    handleSelect(evt) { this.selectedIdx = Number(evt.currentTarget.dataset.idx); }
    handleKey(evt) { if (evt.key === 'Enter' || evt.key === ' ') { evt.preventDefault(); this.handleSelect(evt); } }
    handleOpen(evt) {
        evt.preventDefault();
        const s = this.selected;
        if (s && s.recordId) openRecord((id) => this.goRecord(id), s.recordId, this.isMobile);
    }
    handleSelAction() { const s = this.selected; if (s && s.action) this.run(`n${s.idx}`, s.action); }
    handleAction(evt) {
        const key = evt.currentTarget.dataset.key;
        const a = this.actions.find(x => x.key === key);
        if (a) this.run(key, a);
    }
    async run(key, action) {
        try {
            this.message = await runAction(action, id => openRecord((id) => this.goRecord(id), id, this.isMobile));
            this.done = { ...this.done, [key]: true };
        } catch (e) {
            this.message = `Could not complete that action: ${errorText(e)}`;
        }
    }
}
