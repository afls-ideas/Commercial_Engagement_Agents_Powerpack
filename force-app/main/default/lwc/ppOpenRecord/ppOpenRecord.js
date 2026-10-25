// Key prefix -> object API name, for the lsc:// deeplink path.
const OBJECTS = { '001': 'Account', '003': 'Contact', '00T': 'Task', '500': 'Case', '006': 'Opportunity', '1PO': 'MngEvent' };

/**
 * Opens a record from an Agentforce card. In the Salesforce mobile app (`mobile` true) it tries the
 * lsc:// deeplink first and falls back to standard navigation if the page is still in the foreground
 * afterwards. Everywhere else it navigates normally: an unhandled lsc:// link shows a Safari
 * "address is invalid" alert on desktop. Apex-free so it is safe in mobile cards.
 */
export function openRecord(navigate, recordId, mobile) {
    if (!recordId) return;
    const obj = OBJECTS[String(recordId).substring(0, 3)];
    if (!mobile || !obj) { navigate(recordId); return; }
    let left = false;
    const onHide = () => { left = true; };
    window.addEventListener('pagehide', onHide, { once: true });
    document.addEventListener('visibilitychange', onHide, { once: true });
    try {
        window.location.href = `lsc://deeplink/lightning/r/${obj}/${recordId}/view`;
    } catch (e) {
        navigate(recordId);
        return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
        window.removeEventListener('pagehide', onHide);
        document.removeEventListener('visibilitychange', onHide);
        if (!left) navigate(recordId);
    }, 1200);
}
