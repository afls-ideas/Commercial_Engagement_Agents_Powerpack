#!/usr/bin/env python3
"""Generate PP_Scenario_Fact__mdt records from a TSV. Columns: key<TAB>persona<TAB>account<TAB>category<TAB>fact. Usage: gen_facts.py <facts.tsv> <out_dir>"""
import sys, re
from xml.sax.saxutils import escape
src, out = sys.argv[1:3]
for line in open(src):
    line = line.rstrip('\n')
    if not line.strip() or line.startswith('#'): continue
    key, persona, acct, cat, fact = line.split('\t')
    def fld(n, v):
        if not v: return ''
        return f'    <values>\n        <field>{n}</field>\n        <value xsi:type="xsd:string">{escape(v)}</value>\n    </values>\n'
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">\n'
           f'    <label>{escape(key)}</label>\n    <protected>false</protected>\n'
           + fld('Account_Name__c', acct) + fld('Category__c', cat) + fld('Fact__c', fact) + fld('Persona__c', persona)
           + '</CustomMetadata>\n')
    name = re.sub(r'[^A-Za-z0-9]+', '_', key).strip('_')
    open(f'{out}/PP_Scenario_Fact.{name}.md-meta.xml', 'w').write(xml)
