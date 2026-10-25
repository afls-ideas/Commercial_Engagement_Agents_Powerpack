#!/usr/bin/env python3
"""Generate a genAiPromptTemplate XML from a text file. Usage: gen_template.py <DevName> "<Label>" <content.txt> <out_dir> [Input1,Input2,...]"""
import sys, hashlib, base64
from xml.sax.saxutils import escape
dev, label, src, out = sys.argv[1:5]
inputs = sys.argv[5].split(',') if len(sys.argv) > 5 else ['Question', 'AccountContext', 'ScenarioFacts']
content = open(src).read().strip()
vid = base64.b64encode(hashlib.sha256(content.encode()).digest()).decode() + '_1'
ins = ''.join(f"""        <inputs>
            <apiName>{i}</apiName>
            <definition>primitive://String</definition>
            <masterLabel>{i}</masterLabel>
            <referenceName>Input:{i}</referenceName>
            <required>true</required>
        </inputs>
""" for i in inputs)
xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<GenAiPromptTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <activeVersionIdentifier>{vid}</activeVersionIdentifier>
    <developerName>{dev}</developerName>
    <masterLabel>{escape(label)}</masterLabel>
    <templateVersions>
        <content>{escape(content)}</content>
{ins}        <status>Published</status>
        <versionIdentifier>{vid}</versionIdentifier>
    </templateVersions>
    <type>einstein_gpt__flex</type>
    <visibility>Global</visibility>
</GenAiPromptTemplate>
"""
open(f"{out}/{dev}.genAiPromptTemplate-meta.xml", 'w').write(xml)
