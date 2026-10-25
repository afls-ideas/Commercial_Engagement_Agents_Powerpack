import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { parseCard, errorText, runAction } from 'c/ppCardUtil';

const W = 340, H = 270, PL = 34, PR = 12, PT = 12, PB = 30;

export default class PpWhitespaceMapCard extends NavigationMixin(LightningElement) {
    @api value;
    selectedIdx = 0;
    done = {};
    message = '';

    get card() { return parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get viewBox() { return `0 0 ${W} ${H}`; }
    get plotLeft() { return PL; }
    get plotTop() { return PT; }
    get plotRight() { return W - PR; }
    get plotBottom() { return H - PB; }
    get midX() { return PL + (W - PL - PR) / 2; }
    get midY() { return PT + (H - PT - PB) / 2; }
    get halfW() { return (W - PL - PR) / 2; }
    get halfH() { return (H - PT - PB) / 2; }
    get labelBottomY() { return H - 6; }
    get axisYLabelTransform() { return `rotate(-90 9 ${this.midY})`; }
    get axisYLabelY() { return this.midY; }
    get metrics() {
        return ((this.card && this.card.metrics) || []).map((m, i) => ({ ...m, key: `m${i}`, cls: `pp-metric pp-tone-${m.tone || 'neutral'}` }));
    }
    get accounts() {
        const list = (this.card && this.card.accounts) || [];
        const maxRev = Math.max(1, ...list.map(a => Number(a.revenue) || 0));
        const placed = [];
        return list.map((a, i) => {
            const share = Math.max(0, Math.min(100, Number(a.share) || 0));
            const pot = Math.max(0, Math.min(100, Number(a.potential) || 0));
            const r = 7 + 17 * Math.sqrt((Number(a.revenue) || 0) / maxRev);
            let x = PL + (share / 100) * (W - PL - PR);
            let y = PT + (1 - pot / 100) * (H - PT - PB);
            for (let t = 0; t < 6 && placed.some(p => Math.hypot(p.x - x, p.y - y) < (p.r + r) * 0.7); t++) { x += t % 2 ? -8 : 8; y += 6; }
            x = Math.max(PL + r, Math.min(W - PR - r, x)); y = Math.max(PT + r, Math.min(H - PB - r, y));
            placed.push({ x, y, r });
            const q = (a.quadrant || 'develop').toLowerCase();
            const sel = i === this.selectedIdx;
            return {
                ...a, idx: i, key: `a${i}`, r, transform: `translate(${x} ${y})`, sel,
                initials: (a.account || '?').split(/\s+/).map(w => w[0]).slice(0, 2).join('').toUpperCase(),
                gCls: `ws-pt ws-${q}${sel ? ' ws-sel' : ''}`,
                chipCls: `pp-chip ws-chip-${q}`,
                rowCls: `cm-row${sel ? ' cm-row-selected' : ''}`,
                aria: `${a.account}, ${a.quadrant}, potential ${a.potential}, share ${a.share}`,
                revLabel: `$${a.revenue}K`
            };
        });
    }
    get hasAccounts() { return this.accounts.length > 0; }
    get selected() {
        const a = this.accounts[this.selectedIdx];
        return a ? { ...a, actionLabel: a.action ? (this.done[`a${a.idx}`] ? `${a.action.label} \u2713` : a.action.label) : '',
            actionDisabled: !!this.done[`a${a.idx}`],
            actionCls: a.action && a.action.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn' } : null;
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
        if (s && s.recordId) this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: s.recordId, actionName: 'view' } });
    }
    handleSelAction() { const s = this.selected; if (s && s.action) this.run(`a${s.idx}`, s.action); }
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
