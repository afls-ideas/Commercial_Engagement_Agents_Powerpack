import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { parseCard, errorText, runAction } from 'c/ppCardUtil';

export default class PpQbrCard extends NavigationMixin(LightningElement) {
    @api value;
    done = {};
    message = '';

    get card() { return parseCard(this.value); }
    get hasCard() { return !!this.card; }
    get badgeClass() { return `pp-badge pp-tone-${this.card.badgeTone || 'neutral'}`; }
    get milestones() {
        return ((this.card && this.card.milestones) || []).map((m, i) => {
            const st = (m.status || 'next').toLowerCase();
            const d = m.daysFromToday;
            return { ...m, key: `ms${i}`, cls: `qb-ms qb-ms-${st}`,
                when: d === null || d === undefined ? '' : (d === 0 ? 'today' : (d > 0 ? `in ${d}d` : `${-d}d ago`)),
                shortDate: (m.eventDate || '').slice(5) };
        });
    }
    get hasMilestones() { return this.milestones.length > 0; }
    get scorecard() {
        return ((this.card && this.card.scorecard) || []).map((s, i) => {
            const st = (s.status || '').toLowerCase().replace(/\s+/g, '-');
            const pct = Math.max(0, Math.min(120, Number(s.attainment) || 0));
            return { ...s, key: `sc${i}`, chipCls: `pp-chip qb-chip-${st}`,
                fillCls: `qb-fill qb-fill-${st}`, fillStyle: `width:${Math.min(100, pct)}%`,
                values: `${s.actual} of ${s.plan} ${s.unit || ''}`.trim(), pctText: `${s.attainment}%` };
        });
    }
    get hasScorecard() { return this.scorecard.length > 0; }
    get decisions() {
        return ((this.card && this.card.decisions) || []).map((d, i) => ({
            ...d, key: `d${i}`, hasAction: !!d.action,
            actionLabel: d.action ? (this.done[`d${i}`] ? `${d.action.label} \u2713` : d.action.label) : '',
            actionDisabled: !!this.done[`d${i}`],
            actionCls: d.action && d.action.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'
        }));
    }
    get hasDecisions() { return this.decisions.length > 0; }
    get lanes() {
        return ((this.card && this.card.lanes) || []).map((l, i) => ({
            key: `l${i}`, lane: l.lane,
            actions: (l.actions || []).map((a, j) => ({ ...a, key: `l${i}a${j}` }))
        }));
    }
    get hasLanes() { return this.lanes.length > 0; }
    get metrics() {
        return ((this.card && this.card.metrics) || []).map((m, i) => ({ ...m, key: `m${i}`, cls: `pp-metric pp-tone-${m.tone || 'neutral'}` }));
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

    handleDecision(evt) {
        const key = evt.currentTarget.dataset.key;
        const d = this.decisions.find(x => x.key === key);
        if (d && d.action) this.run(key, d.action);
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
