import createTask from '@salesforce/apex/PPCardActionController.createTask';

/** Parses the Lightning-type value, which arrives as an object or a JSON string. */
export function parseCard(value) {
    if (!value) return null;
    if (typeof value === 'string') {
        try { return JSON.parse(value); } catch (e) { return null; }
    }
    return value;
}

export function errorText(e) {
    const b = e && e.body;
    return (b && (b.message || (b.pageErrors && b.pageErrors[0] && b.pageErrors[0].message))) || (e && e.message) || 'unknown error';
}

/**
 * Runs a card action. kind: copy | open | task | escalate. Returns the message to show.
 * `navigate` is called with a record id for "open".
 */
export async function runAction(action, navigate) {
    if (action.kind === 'copy') {
        await navigator.clipboard.writeText(action.text || '');
        return 'Copied to clipboard.';
    }
    if (action.kind === 'open') {
        navigate(action.recordId);
        return '';
    }
    const escalate = action.kind === 'escalate';
    const subject = `${escalate ? 'ESCALATION: ' : ''}${action.text || action.label}`;
    await createTask({ subject, whatId: action.recordId || null, dueInDays: escalate ? 1 : 3, highPriority: escalate });
    return escalate ? 'Escalation task created.' : 'Follow-up task created.';
}
