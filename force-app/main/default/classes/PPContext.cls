/**
 * Gathers plain-text context for the Power Pack prompt templates. Apex only fetches and flattens data;
 * every judgement (what matters, tone, output shape) is made by the prompt template.
 */
public with sharing class PPContext {

    public static Id resolveAccountId(String accountId, String accountName) {
        if (String.isNotBlank(accountId)) {
            try {
                Id i = Id.valueOf(accountId);
                if (i.getSobjectType() == Account.SObjectType) return i;
            } catch (Exception e) { /* fall through to name */ }
        }
        if (String.isNotBlank(accountName)) {
            String name = accountName.trim();
            String soslTerm = String.escapeSingleQuotes(name);
            List<List<SObject>> sosl = [FIND :soslTerm IN NAME FIELDS RETURNING Account(Id) LIMIT 1];
            if (!sosl.isEmpty() && !sosl[0].isEmpty()) return sosl[0][0].Id;
            String term = '%' + String.escapeSingleQuotes(name) + '%';
            List<Account> m = [SELECT Id FROM Account WHERE Name LIKE :term LIMIT 1];
            if (!m.isEmpty()) return m[0].Id;
        }
        return null;
    }

    /** Persona facts via getAll() (SOQL on this type is not available in the agent runtime), in label order. getAll() truncates long text to 255 characters, so long facts are stored as continuation rows (_p2, _p3). */
    private static List<PP_Scenario_Fact__mdt> factsFor(String persona, Boolean accountOnly) {
        Map<String, PP_Scenario_Fact__mdt> byKey = new Map<String, PP_Scenario_Fact__mdt>();
        for (PP_Scenario_Fact__mdt f : PP_Scenario_Fact__mdt.getAll().values()) {
            if (f.Persona__c == persona && (!accountOnly || String.isNotBlank(f.Account_Name__c))) {
                byKey.put(nz(f.Account_Name__c) + '|' + nz(f.Category__c) + '|' + f.DeveloperName, f);
            }
        }
        List<String> keys = new List<String>(byKey.keySet());
        keys.sort();
        List<PP_Scenario_Fact__mdt> rows = new List<PP_Scenario_Fact__mdt>();
        for (String k : keys) rows.add(byKey.get(k));
        return rows;
    }

    /** Scenario facts from PP_Scenario_Fact__mdt: persona-wide rows plus rows tied to the named account. */
    public static String scenarioFacts(String persona, String accountName) {
        List<String> lines = new List<String>();
        for (PP_Scenario_Fact__mdt f : factsFor(persona, false)) {
            Boolean personaWide = String.isBlank(f.Account_Name__c);
            Boolean matches = !personaWide && String.isNotBlank(accountName)
                && accountName.toLowerCase().contains(f.Account_Name__c.toLowerCase());
            if (personaWide || matches) {
                lines.add('[' + f.Category__c + (personaWide ? '' : ' | ' + f.Account_Name__c) + '] ' + plain(f.Fact__c));
            }
        }
        return lines.isEmpty() ? 'No scenario facts configured.' : String.join(lines, '\n');
    }

    /** Facts about every account named in the facts table (used by territory-level questions). */
    public static String accountFactsForTerritory(String persona) {
        List<String> lines = new List<String>();
        for (PP_Scenario_Fact__mdt f : factsFor(persona, true)) {
            lines.add('[' + f.Account_Name__c + ' | ' + f.Category__c + '] ' + plain(f.Fact__c));
        }
        return String.join(lines, '\n');
    }

    public static String forAccount(Id acctId) {
        List<String> out = new List<String>();
        out.add('TODAY: ' + Date.today().format());

        Account a = [SELECT Id, Name, IsPersonAccount, PersonTitle, Owner.Name
                     FROM Account WHERE Id = :acctId LIMIT 1];
        out.add('ACCOUNT: ' + a.Name + (a.IsPersonAccount ? ' (HCP' + (a.PersonTitle != null ? ', ' + a.PersonTitle : '') + ')' : ' (organisation)')
            + ' | Owner: ' + a.Owner.Name);

        List<AccountContactRelation> acrs = [SELECT Contact.Name, Roles FROM AccountContactRelation WHERE AccountId = :acctId AND IsActive = true LIMIT 15];
        if (!acrs.isEmpty()) {
            List<String> p = new List<String>();
            for (AccountContactRelation r : acrs) p.add(r.Contact.Name + (r.Roles != null ? ' (' + r.Roles + ')' : ''));
            out.add('RELATED CONTACTS: ' + String.join(p, '; '));
        }

        List<String> done = new List<String>();
        for (Visit v : [SELECT Name, ActualVisitStartTime FROM Visit WHERE AccountId = :acctId AND Status = 'Completed'
                        ORDER BY ActualVisitStartTime DESC LIMIT 10]) {
            done.add(v.ActualVisitStartTime == null ? v.Name : v.ActualVisitStartTime.format('yyyy-MM-dd'));
        }
        out.add('COMPLETED VISITS (newest first): ' + (done.isEmpty() ? 'none' : String.join(done, ', ')));

        Datetime nowDt = Datetime.now();
        Date since180 = Date.today().addDays(-180);
        List<String> planned = new List<String>();
        for (Visit v : [SELECT Name, PlannedVisitStartTime FROM Visit WHERE AccountId = :acctId AND Status != 'Completed'
                        AND PlannedVisitStartTime >= :nowDt ORDER BY PlannedVisitStartTime ASC LIMIT 5]) {
            planned.add(v.PlannedVisitStartTime.format('yyyy-MM-dd HH:mm'));
        }
        out.add('PLANNED VISITS: ' + (planned.isEmpty() ? 'none' : String.join(planned, ', ')));

        List<ProviderVisitProdDetailing> dets = [
            SELECT Id, Product.Name, Priority, IsOffLabel, AdditionalInformation, NextPrvdVisitObjectives, PrvdVisitPlannedStartTime
            FROM ProviderVisitProdDetailing
            WHERE ProviderVisitAccountId = :acctId AND PrvdVisitPlannedStartTime >= :since180
            ORDER BY PrvdVisitPlannedStartTime DESC LIMIT 30];
        Map<Id, ProviderVisitProdDetailing> byId = new Map<Id, ProviderVisitProdDetailing>(dets);
        Set<Id> byIdKeys = byId.keySet();
        Map<Id, List<String>> msgs = new Map<Id, List<String>>();
        if (!byId.isEmpty()) {
            for (ProviderVisitDtlProductMsg m : [
                SELECT Name, ReactionType, CapturedReaction, ProviderVisitProductDtlId FROM ProviderVisitDtlProductMsg
                WHERE ProviderVisitProductDtlId IN :byIdKeys ORDER BY CreatedDate DESC LIMIT 100]) {
                if (!msgs.containsKey(m.ProviderVisitProductDtlId)) msgs.put(m.ProviderVisitProductDtlId, new List<String>());
                msgs.get(m.ProviderVisitProductDtlId).add(m.Name + ' => ' + nz(m.ReactionType) + (m.CapturedReaction != null ? ' ("' + m.CapturedReaction + '")' : ''));
            }
        }
        out.add('DETAILING (last 180 days):');
        if (dets.isEmpty()) out.add('  none');
        for (ProviderVisitProdDetailing d : dets) {
            out.add('  ' + (d.PrvdVisitPlannedStartTime == null ? '' : d.PrvdVisitPlannedStartTime.format('yyyy-MM-dd')) + ' | ' + d.Product.Name
                + ' | priority ' + d.Priority + (d.IsOffLabel == true ? ' | OFF-LABEL FLAG' : '')
                + (d.NextPrvdVisitObjectives != null ? ' | next objective: ' + d.NextPrvdVisitObjectives : '')
                + (d.AdditionalInformation != null ? ' | notes: ' + d.AdditionalInformation : ''));
            if (msgs.containsKey(d.Id)) for (String s : msgs.get(d.Id)) out.add('      message: ' + s);
        }

        Set<Id> insightIds = new Set<Id>();
        for (MedicalInsightAccount mia : [SELECT MedicalInsightId FROM MedicalInsightAccount WHERE AccountId = :acctId LIMIT 50]) insightIds.add(mia.MedicalInsightId);
        out.add('MEDICAL INSIGHTS:');
        if (insightIds.isEmpty()) out.add('  none');
        else {
            for (MedicalInsight mi : [SELECT Name, Content, AI_Summary__c FROM MedicalInsight WHERE Id IN :insightIds ORDER BY CreatedDate DESC LIMIT 10]) {
                out.add('  - ' + (mi.AI_Summary__c != null ? mi.AI_Summary__c : trunc(mi.Content, 400)));
            }
        }

        out.add('OPEN TASKS:');
        List<Task> tasks = [SELECT Subject, ActivityDate FROM Task WHERE AccountId = :acctId AND IsClosed = false ORDER BY ActivityDate ASC LIMIT 10];
        if (tasks.isEmpty()) out.add('  none');
        for (Task t : tasks) out.add('  - ' + t.Subject + (t.ActivityDate != null ? ' (due ' + t.ActivityDate.format() + ')' : ''));

        return String.join(out, '\n');
    }

    /** Compact one-line-per-account snapshot of the accounts the rep has visited most, for territory-level questions. */
    public static String territorySnapshot() {
        List<String> out = new List<String>{ 'TODAY: ' + Date.today().format(), 'TERRITORY SNAPSHOT (accounts by completed visits, last 365 days):' };
        Date since365 = Date.today().addDays(-365);
        Date since180 = Date.today().addDays(-180);
        Map<Id, Integer> counts = new Map<Id, Integer>();
        Map<Id, Datetime> last = new Map<Id, Datetime>();
        for (AggregateResult ar : [
            SELECT AccountId a, COUNT(Id) c, MAX(ActualVisitStartTime) l FROM Visit
            WHERE Status = 'Completed' AND AccountId != null AND ActualVisitStartTime >= :since365
            GROUP BY AccountId ORDER BY COUNT(Id) DESC LIMIT 25]) {
            counts.put((Id) ar.get('a'), (Integer) ar.get('c'));
            last.put((Id) ar.get('a'), (Datetime) ar.get('l'));
        }
        Set<Id> acctIds = counts.keySet();
        Map<Id, Integer> detCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT ProviderVisitAccountId a, COUNT(Id) c FROM ProviderVisitProdDetailing
            WHERE ProviderVisitAccountId IN :acctIds AND PrvdVisitPlannedStartTime >= :since180
            GROUP BY ProviderVisitAccountId]) {
            detCounts.put((Id) ar.get('a'), (Integer) ar.get('c'));
        }
        for (Account a : [SELECT Id, Name, IsPersonAccount, PersonTitle FROM Account WHERE Id IN :acctIds]) {
            Datetime l = last.get(a.Id);
            out.add('- ' + a.Name + (a.IsPersonAccount ? ' (HCP' + (a.PersonTitle != null ? ', ' + a.PersonTitle : '') + ')' : '')
                + ' | visits 365d: ' + counts.get(a.Id) + ' | last visit: ' + (l == null ? 'n/a' : l.format('yyyy-MM-dd'))
                + ' | detailings 180d: ' + (detCounts.containsKey(a.Id) ? detCounts.get(a.Id) : 0));
        }
        return String.join(out, '\n');
    }

    /** CRM Account Plan module data for the account: plans, objectives and stakeholders. Missing access or data is reported, not thrown. */
    public static String planContext(Id acctId) {
        List<String> out = new List<String>();
        try {
            List<AccountPlan> plans = [SELECT Id, Name, Status, StartDate, EndDate, ActionPlanCompletedPct, Owner.Name
                                       FROM AccountPlan WHERE AccountId = :acctId ORDER BY CreatedDate DESC LIMIT 5];
            if (plans.isEmpty()) return 'CRM ACCOUNT PLANS: none on file for this account.';
            Set<Id> planIds = new Map<Id, AccountPlan>(plans).keySet();
            out.add('CRM ACCOUNT PLANS:');
            for (AccountPlan p : plans) {
                out.add('- ' + p.Name + ' | status ' + nz(p.Status) + ' | owner ' + p.Owner.Name
                    + ' | start ' + (p.StartDate == null ? 'n/a' : p.StartDate.format()) + ' | end ' + (p.EndDate == null ? 'n/a' : p.EndDate.format())
                    + ' | completion ' + (p.ActionPlanCompletedPct == null ? 'n/a' : String.valueOf(p.ActionPlanCompletedPct)));
            }
            for (AccountPlanObjective o : [SELECT AccountPlan.Name, Name, Status, DueDate FROM AccountPlanObjective WHERE AccountPlanId IN :planIds LIMIT 30]) {
                out.add('  objective [' + o.AccountPlan.Name + ']: ' + o.Name + ' | status ' + nz(o.Status) + ' | due ' + (o.DueDate == null ? 'n/a' : o.DueDate.format()));
            }
            for (AccountPlanStakeholder s : [SELECT AccountPlan.Name, StakeholderName, RoleType, InfluenceLevel FROM AccountPlanStakeholder WHERE AccountPlanId IN :planIds LIMIT 30]) {
                out.add('  stakeholder [' + s.AccountPlan.Name + ']: ' + s.StakeholderName + ' | ' + nz(s.RoleType) + ' | ' + nz(s.InfluenceLevel));
            }
        } catch (Exception e) {
            out.add('CRM ACCOUNT PLANS: unavailable (' + e.getMessage() + ')');
        }
        return String.join(out, '\n');
    }

    /** Raw fact texts for a persona and category (persona-wide rows plus rows tied to the named account). */
    public static List<String> factTexts(String persona, String accountName, String category) {
        List<String> out = new List<String>();
        for (PP_Scenario_Fact__mdt f : factsFor(persona, false)) {
            Boolean personaWide = String.isBlank(f.Account_Name__c);
            Boolean matches = !personaWide && String.isNotBlank(accountName) && accountName.toLowerCase().contains(f.Account_Name__c.toLowerCase());
            if ((personaWide || matches) && f.Category__c == category) out.add(plain(f.Fact__c));
        }
        return out;
    }

    /** Custom metadata text fields come back HTML-encoded (the pipe separator as &#124;). */
    private static String plain(String s) { return s == null ? '' : s.replace('&#124;', '|'); }
    private static String nz(String s) { return s == null ? '' : s; }
    private static String trunc(String s, Integer n) { return s == null ? '' : (s.length() > n ? s.substring(0, n) + '...' : s); }
}
