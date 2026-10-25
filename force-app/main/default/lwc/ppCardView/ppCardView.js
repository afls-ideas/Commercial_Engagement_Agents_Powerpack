import { LightningElement, api } from 'lwc';
import createTask from '@salesforce/apex/PPCardActionController.createTask';
import { openRecord } from 'c/ppOpenRecord';
import { NavigationMixin } from 'lightning/navigation';

const TONES = ['positive', 'warning', 'critical', 'neutral'];
const tone = (t) => (TONES.includes(t) ? t : 'neutral');

/**
 * Shared renderer for the Power Pack PPCard type. Persona renderers set `rowStyle`
 * ('stepper' = ordered pipeline, 'table' = ranked list) and `iconName`.
 * Action buttons: task / escalate create a Task, open navigates, copy copies text.
 */
export default class PpCardView extends NavigationMixin(LightningElement) {
    @api card;
    @api mobile = false;
    @api rowStyle = 'table';
    @api iconName = 'standard:account';

    done = {};
    message = '';

    get hasCard() {
        const c = this.card;
        return !!(c && (c.title || c.headline || (c.rows && c.rows.length) || (c.sections && c.sections.length)));
    }
    get badgeClass() { return `pp-badge pp-tone-${tone(this.card.badgeTone)}`; }
    get hasMetrics() { return !!(this.card.metrics && this.card.metrics.length); }
    get metrics() {
        return (this.card.metrics || []).map((m, i) => ({
            key: `m${i}`, label: m.label, value: m.value, cls: `pp-metric pp-tone-${tone(m.tone)}`
        }));
    }
    get hasRows() { return !!(this.card.rows && this.card.rows.length); }
    get rowsClass() { return `pp-rows pp-rows-${this.rowStyle}`; }
    get rows() {
        return (this.card.rows || []).map((r, i) => {
            const t = tone(r.tone);
            const key = `r${i}`;
            return {
                key, label: r.label, status: r.status, detail: r.detail, action: r.action,
                actionLabel: this.done[key] ? 'Done' : r.action && r.action.label,
                cls: `pp-row pp-tone-${t}`, chipCls: `pp-chip pp-tone-${t}`,
                hasScore: r.score !== null && r.score !== undefined,
                barStyle: `width:${Math.max(0, Math.min(100, r.score || 0))}%`
            };
        });
    }
    get sections() {
        return (this.card.sections || []).map((s, i) => ({
            key: `s${i}`, heading: s.heading,
            bullets: (s.bullets || []).map((text, j) => ({ key: `s${i}b${j}`, text }))
        }));
    }
    get hasActions() { return !!(this.card.actions && this.card.actions.length); }
    get actions() {
        return (this.card.actions || []).map((a, i) => {
            const key = `a${i}`;
            return {
                key, kind: a.kind,
                label: this.done[key] ? `${a.label} ✓` : a.label,
                disabled: !!this.done[key],
                cls: a.kind === 'escalate' ? 'pp-btn pp-btn-escalate' : 'pp-btn'
            };
        });
    }

    goRecord(id) { this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } }); }
    handleAction(evt) { this.run(evt.currentTarget.dataset.key, (this.card.actions || [])[Number(evt.currentTarget.dataset.key.slice(1))]); }
    handleRowAction(evt) { this.run(evt.currentTarget.dataset.key, (this.card.rows || [])[Number(evt.currentTarget.dataset.key.slice(1))].action); }

    async run(key, action) {
        if (!action) return;
        try {
            if (action.kind === 'copy') {
                await navigator.clipboard.writeText(action.text || '');
                this.finish(key, 'Copied to clipboard.');
            } else if (action.kind === 'open') {
                openRecord((id) => this.goRecord(id), action.recordId, this.mobile);
                this.finish(key, '');
            } else {
                const escalate = action.kind === 'escalate';
                const subject = `${escalate ? 'ESCALATION: ' : ''}${action.text || action.label}`;
                await createTask({ subject, whatId: action.recordId || null, dueInDays: escalate ? 1 : 3, highPriority: escalate });
                this.finish(key, escalate ? 'Escalation task created.' : 'Follow-up task created.');
            }
        } catch (e) {
            const out = e && e.body && e.body.output;
            const detail = out ? [...(out.errors || []).map(x => x.message), ...Object.values(out.fieldErrors || {}).flat().map(x => x.message)].join('; ') : '';
            this.message = `Could not complete that action: ${detail || (e && e.body && (e.body.message || (e.body.pageErrors && e.body.pageErrors[0] && e.body.pageErrors[0].message))) || (e && e.message) || 'unknown error'}`;
        }
    }

    finish(key, msg) {
        this.done = { ...this.done, [key]: true };
        this.message = msg;
    }
}
