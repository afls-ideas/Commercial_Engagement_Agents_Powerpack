import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { parseCard, errorText, runAction } from 'c/ppCardUtil';

const TIER = { preferred: 'preferred', alternate: 'alternate', restricted: 'restricted', 'not reviewed': 'none' };
const DAY = 86400000;

export default class PpFormularyMapCard extends NavigationMixin(LightningElement) {
    @api value;
    selectedIdx = 0;
    done = {};
    message = '';

    get card() { return parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get products() { return (this.card && this.card.products) || []; }
    get gridStyle() { return `grid-template-columns: minmax(6rem, 1.4fr) repeat(${this.products.length || 1}, minmax(4.5rem, 1fr));`; }
    get metrics() {
        return ((this.card && this.card.metrics) || []).map((m, i) => ({ ...m, key: `m${i}`, cls: `pp-metric pp-tone-${m.tone || 'neutral'}` }));
    }
    get rows() {
        return ((this.card && this.card.rows) || []).map((r, i) => {
            const cells = this.products.map((p, j) => {
                const c = (r.cells || []).find(x => x.product === p) || { tier: 'Not reviewed' };
                const k = TIER[(c.tier || '').toLowerCase()] || 'none';
                return { key: `r${i}c${j}`, tier: c.tier, cls: `fm-cell fm-${k}` };
            });
            const sel = i === this.selectedIdx;
            const d = r.daysToDecision;
            return {
                ...r, idx: i, key: `r${i}`, cells, sel,
                rowCls: `fm-row${sel ? ' fm-row-sel' : ''}`,
                when: d === null || d === undefined ? 'no date' : (d < 0 ? `${-d}d ago` : `${d}d`),
                whenCls: d !== null && d !== undefined && d >= 0 && d <= 30 ? 'fm-when fm-when-soon' : 'fm-when'
            };
        });
    }
    get selected() {
        const r = this.rows[this.selectedIdx];
        if (!r) return null;
        const src = (this.card.rows || [])[this.selectedIdx] || {};
        const notes = (src.cells || []).map((c, j) => ({ key: `n${j}`, product: c.product, tier: c.tier, note: c.note, cls: `fm-note fm-note-${TIER[(c.tier || '').toLowerCase()] || 'none'}` }));
        const t = this.timeline(src);
        return { ...r, notes, ...t, riskCls: `fm-risk pp-tone-${src.riskTone || 'neutral'}` };
    }
    timeline(r) {
        const now = Date.now();
        const sub = r.submitted ? Date.parse(r.submitted) : NaN;
        const due = r.decisionDue ? Date.parse(r.decisionDue) : NaN;
        if (isNaN(due)) return { hasTimeline: false };
        const start = isNaN(sub) ? Math.min(now, due) - 30 * DAY : sub;
        const end = Math.max(due, now) + 14 * DAY;
        const span = Math.max(end - start, DAY);
        const x = t => 12 + ((t - start) / span) * 296;
        return {
            hasTimeline: true,
            subX: x(start), nowX: x(now), dueX: x(due), barW: Math.max(0, x(Math.min(now, due)) - x(start)),
            hasSub: !isNaN(sub), subLabel: r.submitted || '', dueLabel: r.decisionDue,
            overdue: now > due
        };
    }
    get hasRows() { return this.rows.length > 0; }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    get selActionLabel() { const s = this.selected; return s && s.action ? (this.done[`r${s.idx}`] ? `${s.action.label} \u2713` : s.action.label) : ''; }
    get selActionDisabled() { const s = this.selected; return !!(s && this.done[`r${s.idx}`]); }
    get selActionCls() { const s = this.selected; return s && s.action && s.action.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'; }
    get actions() {
        return ((this.card && this.card.actions) || []).map((a, i) => ({
            ...a, key: `a${i}`, label: this.done[`a${i}`] ? `${a.label} \u2713` : a.label,
            disabled: !!this.done[`a${i}`], cls: a.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'
        }));
    }
    get hasActions() { return this.actions.length > 0; }

    handleSelect(evt) { this.selectedIdx = Number(evt.currentTarget.dataset.idx); }
    handleKey(evt) { if (evt.key === 'Enter' || evt.key === ' ') { evt.preventDefault(); this.handleSelect(evt); } }
    handleOpen(evt) {
        evt.preventDefault();
        const s = this.selected;
        if (s && s.recordId) this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: s.recordId, actionName: 'view' } });
    }
    handleRowAction() { const s = this.selected; if (s && s.action) this.run(`r${s.idx}`, s.action); }
    handleAction(evt) {
        const key = evt.currentTarget.dataset.key;
        const a = this.actions.find(x => x.key === key);
        if (a) this.run(key, a);
    }
    async run(key, action) {
        try {
            this.message = await runAction(action, id => this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } }));
            this.done = { ...this.done, [key]: true };
        } catch (e) {
            this.message = `Could not complete that action: ${errorText(e)}`;
        }
    }
}
