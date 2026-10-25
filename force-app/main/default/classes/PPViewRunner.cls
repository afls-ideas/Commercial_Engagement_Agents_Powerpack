/** Shared plumbing for the account-plan view actions: resolve the account, run a prompt template, return JSON that parses. */
public with sharing class PPViewRunner {

    /** Runs the template and returns the JSON object text, retrying once because LLM JSON is occasionally malformed. Null if both attempts fail. */
    public static String runJson(String templateName, Map<String, String> inputs) {
        for (Integer attempt = 0; attempt < 2; attempt++) {
            String s = PPPromptRunner.run(templateName, inputs);
            s = s == null ? '' : s.trim();
            Integer a = s.indexOf('{');
            Integer b = s.lastIndexOf('}');
            if (a < 0 || b <= a) continue;
            String body = s.substring(a, b + 1);
            try {
                JSON.deserializeUntyped(body);
                return body;
            } catch (Exception e) { /* retry */ }
        }
        return null;
    }

    /** Points any action with no record of its own at the account, so "open" buttons work. */
    public static void defaultRecord(List<PPAction> actions, Id acctId) {
        if (actions == null) return;
        for (PPAction a : actions) if (String.isBlank(a.recordId)) a.recordId = acctId;
    }

    public static PPSection section(String heading, String body) {
        PPSection sec = new PPSection();
        sec.heading = heading;
        sec.bullets = new List<String>{ body };
        return sec;
    }

    /** Best-effort link from a free-text account name to an Account record; null when nothing matches. */
    public static Id linkAccount(String name) {
        if (String.isBlank(name)) return null;
        String term = '%' + String.escapeSingleQuotes(name.trim()) + '%';
        List<Account> m = [SELECT Id FROM Account WHERE Name LIKE :term ORDER BY Name LIMIT 1];
        return m.isEmpty() ? null : m[0].Id;
    }

    public static Date parseDate(String s) {
        if (String.isBlank(s)) return null;
        try { return Date.valueOf(s.trim().left(10)); } catch (Exception e) { return null; }
    }

    /** Lowercase name with title and credentials stripped ("Dr. Raj Menon, PharmD" -> "raj menon"), for matching to person accounts. */
    public static String bareName(String name) {
        String n = name.replaceFirst('^(Dr\\.|Prof\\.)\\s*', '');
        Integer comma = n.indexOf(',');
        if (comma > 0) n = n.substring(0, comma);
        return n.trim().toLowerCase();
    }
}
