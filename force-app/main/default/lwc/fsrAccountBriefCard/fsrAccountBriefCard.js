import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

/**
 * Renders the FSRAccountBrief custom Lightning type as a structured summary
 * card in an Agentforce response: a headline, one or more sections (each a
 * heading with its own bullet list), and a highlighted next step.
 *
 * The typed action output arrives on the CLT-standard `value` property.
 */
export default class FsrAccountBriefCard extends LightningElement {
    _val;
    _mob = null;

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

    get _brief() {
        if (!this.value) {
            return null;
        }
        if (typeof this.value === 'string') {
            try {
                return JSON.parse(this.value);
            } catch (e) {
                return null;
            }
        }
        return this.value;
    }

    get hasBrief() {
        const b = this._brief;
        return !!(b && (b.accountName || b.headline || (b.sections && b.sections.length)));
    }

    get accountName() {
        return this._brief?.accountName || 'Account';
    }

    get subtitle() {
        return this._brief?.subtitle;
    }

    get headline() {
        return this._brief?.headline;
    }

    get hasHeadline() {
        return !!this._brief?.headline;
    }

    // Give each section and bullet a stable key for iteration.
    get sections() {
        const secs = this._brief?.sections || [];
        return secs.map((s, i) => ({
            key: `sec-${i}`,
            heading: s.heading,
            bullets: (s.bullets || []).map((text, j) => ({
                key: `sec-${i}-b-${j}`,
                text
            }))
        }));
    }

    get hasSections() {
        return this.sections.length > 0;
    }

    get nextStep() {
        return this._brief?.nextStep;
    }

    get hasNextStep() {
        return !!this._brief?.nextStep;
    }
}
