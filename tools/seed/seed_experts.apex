// Seeds a speaker pool for the Speaker Search agent: Experts on existing person accounts, with product qualifications
// (ExpertSubject) and speaker details in AdditionalInformation. Safe to run again: accounts that already have an Expert are skipped.
// Run: sf apex run -f tools/seed/seed_experts.apex -o <org>
Map<String, Id> subjects = new Map<String, Id>();
for (Subject s : [SELECT Id, Name FROM Subject]) subjects.put(s.Name, s.Id);
// name | status | specialty | tier | fee | trained | products (comma separated)
List<List<String>> rows = new List<List<String>>{
    new List<String>{ 'Christine Walsh', 'Approved', 'Medical Oncology', '2', '2500', '2026-03-10', 'Immunexis' },
    new List<String>{ 'Raymond Lee', 'Approved', 'Hematology-Oncology', '1', '3000', '2025-04-02', 'Immunexis' },
    new List<String>{ 'Susan Chen', 'Nominated', 'Medical Oncology', '2', '2500', '', 'Immunexis' },
    new List<String>{ 'Patrick O\'Brien', 'Approved', 'Cardiology', '2', '2500', '2026-01-20', 'Cordim' },
    new List<String>{ 'Amy Anderson', 'Approved', 'Medical Oncology', '1', '3500', '2026-02-15', 'Immunexis' },
    new List<String>{ 'Brian Larson', 'Approved', 'Hematology-Oncology', '3', '1800', '2026-05-05', 'Immunexis' },
    new List<String>{ 'Jennifer Olson', 'Rejected', 'Medical Oncology', '2', '2500', '', 'Immunexis' },
    new List<String>{ 'Sarah Mitchell', 'Approved', 'Medical Oncology', '2', '2500', '2026-04-12', 'Immunexis' },
    new List<String>{ 'Thomas Brennan', 'Approved', 'Hematology-Oncology', '3', '1800', '2026-06-01', 'Immunexis' }
};
Set<String> names = new Set<String>();
for (List<String> r : rows) names.add(r[0]);
Map<String, Account> accts = new Map<String, Account>();
for (Account a : [SELECT Id, Name FROM Account WHERE IsPersonAccount = true AND Name IN :names]) accts.put(a.Name, a);
Set<Id> have = new Set<Id>();
for (Expert e : [SELECT AccountId FROM Expert WHERE AccountId IN :accts.values()]) have.add(e.AccountId);
List<Expert> experts = new List<Expert>();
List<List<String>> made = new List<List<String>>();
for (List<String> r : rows) {
    Account a = accts.get(r[0]);
    if (a == null || have.contains(a.Id)) continue;
    experts.add(new Expert(Name = r[0] + ' Speaker Profile', AccountId = a.Id, Status = r[1], IsActive = true,
        AdditionalInformation = 'SPECIALTY: ' + r[2] + ' | TIER: ' + r[3] + ' | FEE: ' + r[4] + (r[5] == '' ? '' : ' | TRAINED: ' + r[5])));
    made.add(r);
}
insert experts;
List<ExpertSubject> subs = new List<ExpertSubject>();
for (Integer i = 0; i < experts.size(); i++) {
    for (String p : made[i][6].split(',')) {
        if (subjects.containsKey(p)) subs.add(new ExpertSubject(Name = made[i][0] + ' - ' + p, ExpertId = experts[i].Id,
            SubjectId = subjects.get(p), EffectiveDateTime = Datetime.newInstance(2026, 1, 1)));
    }
}
insert subs;
System.debug('Seeded ' + experts.size() + ' experts and ' + subs.size() + ' qualifications');
