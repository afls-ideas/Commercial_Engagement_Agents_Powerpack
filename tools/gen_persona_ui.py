#!/usr/bin/env python3
"""Generate a persona LWC renderer + custom Lightning type bound to the shared PPCard Apex type.
Usage: gen_persona_ui.py <lwcName> <cltName> "<Label>" <rowStyle> <icon>"""
import sys, os, json
lwc, clt, label, style, icon = sys.argv[1:6]
base = 'force-app/main/default'
d = f'{base}/lwc/{lwc}'; os.makedirs(d, exist_ok=True)
tag = 'c-pp-card-view'
open(f'{d}/{lwc}.html', 'w').write(f'<template>\n    <{tag} card={{card}} row-style="{style}" icon-name="{icon}"></{tag}>\n</template>\n')
open(f'{d}/{lwc}.js', 'w').write("""import { LightningElement, api } from 'lwc';

export default class %s extends LightningElement {
    @api value;

    get card() {
        if (!this.value) return null;
        if (typeof this.value === 'string') {
            try { return JSON.parse(this.value); } catch (e) { return null; }
        }
        return this.value;
    }
}
""" % (lwc[0].upper() + lwc[1:]))
open(f'{d}/{lwc}.js-meta.xml', 'w').write(f"""<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>68.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>{label}</masterLabel>
    <description>Renders the {label} custom Lightning type in an Agentforce Employee agent.</description>
    <targets>
        <target>lightning__AgentforceOutput</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__AgentforceOutput">
            <sourceType name="c__{clt}"/>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
""")
t = f'{base}/lightningTypes/{clt}'; os.makedirs(f'{t}/lightningDesktopGenAi', exist_ok=True)
json.dump({"title": label, "description": f"{label} card rendered in a Power Pack Agentforce agent.", "lightning:type": "@apexClassType/c__PPCard"}, open(f'{t}/schema.json', 'w'), indent=2)
json.dump({"renderer": {"componentOverrides": {"$": {"definition": f"c/{lwc}"}}}}, open(f'{t}/lightningDesktopGenAi/renderer.json', 'w'), indent=2)
