import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createTask from '@salesforce/apex/PPCardActionController.createTask';

const W = 340, H = 250, PL = 34, PR = 12, PT = 12, PB = 30;
const STANCE_CLASS = { champion: 'champion', supporter: 'supporter', neutral: 'neutral', skeptic: 'skeptic', blocker: 'blocker' };

export default class PpCommitteeMapCard extends NavigationMixin(LightningElement) {
    @api value;
    selectedIdx;
    done = {};
    message = '';

    get card() {
        if (!this.value) return null;
        if (typeof this.value === 'string') {
            try { return JSON.parse(this.value); } catch (e) { return null; }
        }
        return this.value;
    }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get viewBox() { return `0 0 ${W} ${H}`; }
    get midX() { return PL + (W - PL - PR) / 2; }
    get midY() { return PT + (H - PT - PB) / 2; }
    get halfW() { return (W - PL - PR) / 2; }
    get halfH() { return (H - PT - PB) / 2; }
    get plotRight() { return W - PR; }
    get plotBottom() { return H - PB; }
    get plotLeft() { return PL; }
    get plotTop() { return PT; }
    get axisYLabelTransform() { return `rotate(-90 9 ${this.midY})`; }
    get axisYLabelY() { return this.midY; }
    get labelBottomY() { return H - 6; }
    get labelRightX() { return W - PR; }

    get members() {
        const ms = (this.card && this.card.members) || [];
        const placed = [];
        return ms.map((m, i) => {
            const pos = Math.max(-100, Math.min(100, Number(m.position) || 0));
            const inf = Math.max(0, Math.min(100, Number(m.influence) || 0));
            let x = PL + ((pos + 100) / 200) * (W - PL - PR);
            let y = PT + (1 - Math.max(0, inf - 30) / 70) * (H - PT - PB);
            for (let t = 0; t < 8 && placed.some(p => Math.hypot(p.x - x, p.y - y) < 24); t++) {
                x += t % 2 ? -12 : 12; y += 14;
            }
            x = Math.max(PL + 12, Math.min(W - PR - 12, x)); y = Math.max(PT + 12, Math.min(H - PB - 12, y));
            placed.push({ x, y });
            const stanceKey = STANCE_CLASS[(m.stance || '').toLowerCase()] || 'neutral';
            const selected = i === this.currentIdx;
            const initials = (m.name || '?').replace(/^(Dr\.|Prof\.)\s*/i, '').split(/\s+/).map(w => w[0]).slice(0, 2).join('').toUpperCase();
            return {
                ...m, idx: i, key: `m${i}`, initials, stanceKey, selected,
                transform: `translate(${x} ${y})`,
                r: m.isVoter === false ? 10 : 13,
                gCls: `cm-pt cm-${stanceKey}${m.isVoter === false ? ' cm-advisory' : ''}${selected ? ' cm-selected' : ''}`,
                rowCls: `cm-row${selected ? ' cm-row-selected' : ''}`,
                chipCls: `pp-chip cm-chip-${stanceKey}`,
                aria: `${m.name}, ${m.stance}, influence ${m.influence}`,
                voterLabel: m.isVoter === false ? 'Advisory' : 'Votes'
            };
        });
    }
    get currentIdx() {
        const ms = (this.card && this.card.members) || [];
        if (this.selectedIdx !== undefined && ms[this.selectedIdx]) return this.selectedIdx;
        let best = -1;
        ms.forEach((m, i) => {
            const risk = (m.stance || '').toLowerCase() !== 'champion';
            if (risk && (best < 0 || (m.influence || 0) > (ms[best].influence || 0))) best = i;
        });
        return best < 0 ? 0 : best;
    }
    get hasMembers() { return this.members.length > 0; }
    get selected() { return this.members.find(m => m.selected); }
    get selectedActionLabel() {
        const s = this.selected;
        return s && s.action ? (this.done[`m${s.idx}`] ? `${s.action.label} ✓` : s.action.label) : '';
    }
    get selectedActionDisabled() { const s = this.selected; return !!(s && this.done[`m${s.idx}`]); }
    get selectedActionCls() { const s = this.selected; return s && s.action && s.action.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'; }
    get metrics() {
        const c = this.card || {};
        const out = [];
        if (c.decision) out.push({ key: 'd', label: c.decision, value: c.decisionDate || 'date unknown' });
        if (c.votesNeeded) out.push({ key: 'v', label: 'Votes', value: c.votesNeeded });
        return out;
    }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    get actions() {
        return ((this.card && this.card.actions) || []).map((a, i) => ({
            ...a, key: `a${i}`, label: this.done[`a${i}`] ? `${a.label} ✓` : a.label,
            disabled: !!this.done[`a${i}`], cls: a.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'
        }));
    }
    get hasActions() { return this.actions.length > 0; }

    handleSelect(evt) {
        const idx = Number(evt.currentTarget.dataset.idx);
        this.selectedIdx = idx;
    }
    handleOpenMember(evt) {
        evt.preventDefault(); evt.stopPropagation();
        const s = this.selected;
        if (s && s.recordId) this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: s.recordId, actionName: 'view' } });
    }
    handleKey(evt) {
        if (evt.key === 'Enter' || evt.key === ' ') { evt.preventDefault(); this.handleSelect(evt); }
    }
    handleMemberAction() {
        const s = this.selected;
        if (s && s.action) this.run(`m${s.idx}`, s.action);
    }
    handleAction(evt) {
        const key = evt.currentTarget.dataset.key;
        const a = this.actions.find(x => x.key === key);
        if (a) this.run(key, a);
    }
    finish(key, msg) { this.done = { ...this.done, [key]: true }; this.message = msg; }

    async run(key, action) {
        try {
            if (action.kind === 'copy') {
                await navigator.clipboard.writeText(action.text || '');
                this.finish(key, 'Copied to clipboard.');
            } else if (action.kind === 'open') {
                this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: action.recordId, actionName: 'view' } });
                this.finish(key, '');
            } else {
                const escalate = action.kind === 'escalate';
                const subject = `${escalate ? 'ESCALATION: ' : ''}${action.text || action.label}`;
                await createTask({ subject, whatId: action.recordId || null, dueInDays: escalate ? 1 : 3, highPriority: escalate });
                this.finish(key, escalate ? 'Escalation task created.' : 'Follow-up task created.');
            }
        } catch (e) {
            const b = e && e.body;
            this.message = `Could not complete that action: ${(b && (b.message || (b.pageErrors && b.pageErrors[0] && b.pageErrors[0].message))) || (e && e.message) || 'unknown error'}`;
        }
    }
}
