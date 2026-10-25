import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { parseCard, errorText, runAction } from 'c/ppCardUtil';

const R = 52, CX = 70, CY = 66, ARC = Math.PI * R;
const STATUS_TONE = { 'on track': 'positive', 'at risk': 'warning', 'off track': 'critical', 'not started': 'neutral' };

export default class PpAccountPlanCard extends NavigationMixin(LightningElement) {
    @api value;
    open = {};
    done = {};
    message = '';

    get card() { return parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }

    get health() { return Math.max(0, Math.min(100, Number(this.card.planHealth) || 0)); }
    get hasHealth() { return this.card && this.card.planHealth !== undefined && this.card.planHealth !== null; }
    get gaugePath() { return `M ${CX - R} ${CY} A ${R} ${R} 0 0 1 ${CX + R} ${CY}`; }
    get gaugeDash() { return `${(this.health / 100) * ARC} ${ARC}`; }
    get gaugeCls() { return `ap-gauge-fill ap-g-${this.card.badgeTone || 'neutral'}`; }

    get objectives() {
        return ((this.card && this.card.objectives) || []).map((o, i) => {
            const tone = STATUS_TONE[(o.status || '').toLowerCase()] || 'neutral';
            const p = Math.max(0, Math.min(100, Number(o.progress) || 0));
            const isOpen = !!this.open[i];
            return {
                ...o, key: `o${i}`, idx: i, tone, isOpen,
                fillStyle: `width:${p}%`, pct: `${p}%`,
                chipCls: `pp-chip pp-tone-${tone}`,
                fillCls: `ap-fill ap-fill-${tone}`,
                nodeCls: `ap-node ap-node-${tone}`,
                toggleLabel: isOpen ? 'Hide initiatives' : 'Show initiatives',
                hasInitiatives: !!(o.initiatives && o.initiatives.length),
                kids: (o.initiatives || []).map((t, j) => ({ key: `o${i}k${j}`, text: t })),
                actionLabel: o.action ? (this.done[`o${i}`] ? `${o.action.label} \u2713` : o.action.label) : '',
                actionDisabled: !!this.done[`o${i}`],
                actionCls: o.action && o.action.kind === 'escalate' ? 'pp-btn pp-btn-small pp-btn-escalate' : 'pp-btn pp-btn-small'
            };
        });
    }
    get swot() {
        const order = ['strengths', 'weaknesses', 'opportunities', 'threats'];
        return ((this.card && this.card.swot) || []).map((s, i) => {
            const k = order.indexOf((s.heading || '').toLowerCase());
            return { key: `w${i}`, heading: s.heading, cls: `ap-swot ap-swot-${k < 0 ? 'x' : order[k]}`,
                bullets: (s.bullets || []).map((b, j) => ({ key: `w${i}${j}`, text: b })) };
        });
    }
    get hasSwot() { return this.swot.length > 0; }
    get sections() {
        return ((this.card && this.card.sections) || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading, bullets: (s.bullets || []).map((b, j) => ({ key: `b${i}${j}`, text: b }))
        }));
    }
    get actions() {
        return ((this.card && this.card.actions) || []).map((a, i) => ({
            ...a, key: `a${i}`, label: this.done[`a${i}`] ? `${a.label} \u2713` : a.label,
            disabled: !!this.done[`a${i}`], cls: a.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'
        }));
    }
    get hasActions() { return this.actions.length > 0; }

    handleToggle(evt) {
        const i = Number(evt.currentTarget.dataset.idx);
        this.open = { ...this.open, [i]: !this.open[i] };
    }
    handleObjAction(evt) {
        const i = Number(evt.currentTarget.dataset.idx);
        const o = this.card.objectives[i];
        if (o && o.action) this.run(`o${i}`, o.action);
    }
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
