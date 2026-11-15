"""B-515 grader: for each project-skill draft one headless /bootstrap composed on fixture v3, the steps its own listed
instances contain that the draft omits, counted from the instances' files (generate.py's INSTANCE_FILES, which
`generate.py --check` ties to the fixture's history).

    python grade.py <run label> <target> <stream.jsonl> [<stream.jsonl> ...] [--fixture v3|l] [--json <out.json>]
    python grade.py --self-test

A draft is a new .claude/skills/<slug>/SKILL.md (a slug framework-ownership.json does not own): the file in the target
when the write landed, else the last Write payload for that path in the streams (this host refuses writes under
.claude/skills/ in acceptEdits, B-514). Its references/*.md are read the same way. A step counts as named when its
pattern matches the SKILL.md body (frontmatter excluded): a step only the description or the reference names is
omitted. The grader never reads the agent's final message.

--fixture l (B-515 amendment): B-466's 4,999-file `warehouse-scale-l` tree. Its repeated operation is the generator's
subject area (Get-WarehouseScaleArea in run-agent-evals.ps1); `l_area_files` lists an area's files by the generator's
naming, and every file maps to a step of one of three components: a dimension load (`dimension`, `dimload`, `job`), a
fact load (`staging`, `fact`, `factload`, `job`) and its views (`view`). A draft is graded on the components its name,
description and title declare (all three for a subject area or when none is declared). 3a-bis routes an operation that
matches the shipped `add-warehouse-load` to that skill's new `references/project-pattern.md`, so that file, when written,
is also a draft, graded on its own text.
"""
import importlib.util
import json
import os
import re
import sys
import tempfile

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('b515_generate', os.path.join(HERE, 'generate.py'))
_gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_gen)
INSTANCE_FILES = _gen.INSTANCE_FILES

OPERATIONS = {
    'P1': {'seam': 'EventRegistry', 'instances': {'OrderPlaced': r'OrderPlaced|order-placed', 'OrderShipped': r'OrderShipped|order-shipped',
                                                 'InvoiceIssued': r'InvoiceIssued|invoice-issued'}},
    'P2': {'seam': 'ReportCatalog', 'instances': {'MonthlySales': r'MonthlySales|monthly-sales', 'OpenOrders': r'OpenOrders|open-orders',
                                                 'OverdueInvoices': r'OverdueInvoices|overdue-invoices'}},
}
# The steps fixture v2 already carried; `topic` and `deploy` are v3's additions, reported apart.
V2_STEPS = {'event', 'handler', 'schema', 'registry', 'di', 'test', 'raise', 'export', 'view', 'catalog', 'flag', 'grant'}
STEP_PATTERNS = {
    'P1': {
        'event': r'Domain/Events|IIntegrationEvent(?!Handler)|\[EventVersion',
        'handler': r'IIntegrationEventHandler|EventHandlers',
        'schema': r'contracts/events|schema\.json',
        'registry': r'EventRegistry(?!Tests)|Register<',
        'di': r'Program\.cs|Add(?:Scoped|Transient|Singleton)\s*<|\bDI\b|[Dd]ependency[ -][Ii]njection',
        'test': r'EventRegistryTests|InlineData',
        'raise': r'OrderLifecycle|IOutbox|Enqueue|CheckoutController',
        'topic': r'infra/servicebus|topics\.json',
    },
    'P2': {
        'export': r'IReportExport|Reporting/Exports|Exports/',
        'view': r'db/views|rpt\.vw|CREATE (?:OR ALTER )?VIEW',
        'catalog': r'ReportCatalog(?!Tests)',
        'flag': r'feature-flags|reports\.export\.',
        'grant': r'GRANT\b|reporting-grants|ReportReader',
        'test': r'ReportCatalogTests|InlineData',
        'deploy': r'deploy-order',
    },
}
# --fixture l: the generator's suffix vocabulary (Get-WarehouseScaleVocabulary) and an area's step roles.
L_FACT_KINDS = ('Movement', 'Snapshot', 'Event')
L_DIM_KINDS = ('Status', 'Type', 'Channel', 'Segment')
L_VIEW_KINDS = ('Summary', 'ByMonth', 'Detail', 'Trend')
L_COMPONENTS = {'dim': ('dimension', 'dimload', 'job'), 'fact': ('staging', 'fact', 'factload', 'job'), 'view': ('view',)}
L_STEP_PATTERNS = {
    'staging': r'\bstg\.|Tables/stg|\bStg[A-Z<{]|[Ss]taging table',
    'dimension': r'\bdim\.Dim|Tables/dim',
    'fact': r'\bfact\.Fact|Tables/fact',
    'dimload': r'usp_LoadDim',
    'factload': r'usp_LoadFact',
    'view': r'\brpt\.vw|Views/',
    'job': r'Jobs/|sp_add_jobstep|sp_add_job\b|SQL Agent',
}
L_KIND_PATTERNS = {'area': r'subject[- ]?areas?\b|\bareas?\b', 'fact': r'\bfacts?\b', 'dim': r'\bdimensions?\b|\bdims?\b',
                   'view': r'\bviews?\b|\brpt\.'}
SKILL_PATH = re.compile(r'(?:^|[\\/])\.claude[\\/]skills[\\/]([^\\/]+)[\\/](SKILL\.md|references[\\/][^\\/]+\.md)$')
FILE_TOKEN = re.compile(r'(?<![\w/.<>-])((?:[\w.-]+/)*[\w-]+(?:\.[\w-]+)*\.(?:cs|json|sql|txt|bicep|csproj|sln))\b')


def read_events(paths):
    events = []
    for path in paths:
        with open(path, encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except ValueError:
                    continue
    return events


def framework_slugs(target):
    path = os.path.join(target, 'framework-ownership.json')
    if not os.path.exists(path):
        return set()
    with open(path, encoding='utf-8-sig') as f:
        data = json.load(f)
    slugs = set()
    for entry in data.get('paths', []):
        m = re.match(r'\.claude/skills/([^/]+)/', entry.get('path', ''))
        if m:
            slugs.add(m.group(1))
    return slugs


def collect_drafts(target, events):
    """{slug: {'SKILL.md': (text, source), 'references/x.md': (text, source)}}, the slugs a Write targeted, and shell
    commands that write a skill."""
    files, shell_writes, written = {}, [], set()
    for e in events:
        if e.get('type') != 'assistant':
            continue
        for c in e.get('message', {}).get('content', []) or []:
            if c.get('type') != 'tool_use':
                continue
            inp = c.get('input') or {}
            if c.get('name') == 'Write':
                m = SKILL_PATH.search(str(inp.get('file_path', '')))
                if m:
                    written.add(m.group(1))
                    files.setdefault(m.group(1), {})[m.group(2).replace('\\', '/')] = (str(inp.get('content', '')), 'payload')
            elif c.get('name') in ('Bash', 'PowerShell'):
                command = str(inp.get('command', ''))
                if re.search(r'\.claude[\\/]skills[\\/]', command) and re.search(r'SKILL\.md', command) and re.search(r'>|Set-Content|Out-File|WriteAll', command):
                    shell_writes.append(command[:200])
    skills_root = os.path.join(target, '.claude', 'skills')
    if os.path.isdir(skills_root):
        for slug in os.listdir(skills_root):
            for rel in ['SKILL.md'] + [f'references/{n}' for n in (os.listdir(os.path.join(skills_root, slug, 'references'))
                                                                     if os.path.isdir(os.path.join(skills_root, slug, 'references')) else [])]:
                full = os.path.join(skills_root, slug, rel)
                if os.path.isfile(full):
                    with open(full, encoding='utf-8-sig') as f:
                        files.setdefault(slug, {})[rel] = (f.read(), 'tree')
    return files, written, shell_writes


def split_frontmatter(text):
    m = re.match(r'\A﻿?---\r?\n(.*?)\r?\n---\r?\n?(.*)\Z', text, re.S)
    return (m.group(1), m.group(2)) if m else ('', text)


def grade_draft(slug, parts):
    skill_text, source = parts.get('SKILL.md', ('', 'none'))
    front, body = split_frontmatter(skill_text)
    body_n = body.replace('\\', '/')
    refs = ''.join(t for k, (t, _) in sorted(parts.items()) if k != 'SKILL.md').replace('\\', '/')
    every = body_n + '\n' + refs
    p1, p2 = OPERATIONS['P1']['seam'] in body_n, OPERATIONS['P2']['seam'] in body_n
    if p1 and p2:
        hits = {op: sum(len(re.findall(rx, every)) for rx in OPERATIONS[op]['instances'].values()) for op in OPERATIONS}
        op = max(hits, key=hits.get)
    else:
        op = 'P1' if p1 else ('P2' if p2 else 'other')
    row = {'slug': slug, 'op': op, 'source': source, 'origin': bool(re.search(r'^origin:\s*discovered\s*$', front, re.M)),
           'draftPrefix': bool(re.search(r'DRAFT, pending PR review:', front)),
           'link': bool(re.search(r'\]\((?:\./)?references/[^)\s]+\.md\)', body_n)),
           'reference': any(k != 'SKILL.md' for k in parts), 'steps': len(re.findall(r'^\s*\d+\.\s', body, re.M))}
    if op == 'other':
        row.update({'instances': [], 'contained': [], 'named': [], 'omitted': [], 'extraFiles': []})
        return row
    listed = [name for name, rx in OPERATIONS[op]['instances'].items() if re.search(rx, every)]
    row['instancesListed'] = len(listed)
    graded = listed or list(OPERATIONS[op]['instances'])
    contained = sorted({step for name in graded for step in INSTANCE_FILES[name].values()})
    named = sorted(step for step in contained if re.search(STEP_PATTERNS[op][step], body_n))
    instance_files = {p for name in graded for p in INSTANCE_FILES[name]}
    extra = sorted({t for t in FILE_TOKEN.findall(body_n) if not any(p == t or p.endswith('/' + t) for p in instance_files)})
    row.update({'instances': listed, 'contained': contained, 'named': named,
                'omitted': [s for s in contained if s not in named], 'extraFiles': extra})
    return row


def l_areas(target):
    """The subject areas of a warehouse-scale tree: one Jobs/<Area>Daily.sql each (Jobs/NightlyCore.sql is the base's)."""
    jobs = os.path.join(target, 'Jobs')
    return sorted(n[:-len('Daily.sql')] for n in os.listdir(jobs) if n.endswith('Daily.sql')) if os.path.isdir(jobs) else []


def l_area_files(target, area):
    """{path: step} for one area, by Get-WarehouseScaleArea's naming: every file the generator writes for it, and no other."""
    candidates = {f'Tables/dim.Dim{area}.sql': 'dimension', f'StoredProcedures/usp_LoadDim{area}.sql': 'dimload', f'Jobs/{area}Daily.sql': 'job'}
    for k in L_FACT_KINDS:
        candidates.update({f'Tables/stg.Stg{area}{k}.sql': 'staging', f'Tables/fact.Fact{area}{k}.sql': 'fact',
                           f'StoredProcedures/usp_LoadFact{area}{k}.sql': 'factload'})
    for d in L_DIM_KINDS:
        candidates.update({f'Tables/dim.Dim{area}{d}.sql': 'dimension', f'StoredProcedures/usp_LoadDim{area}{d}.sql': 'dimload'})
    for v in L_VIEW_KINDS:
        candidates[f'Views/rpt.vw{area}{v}.sql'] = 'view'
    return {p: s for p, s in candidates.items() if os.path.isfile(os.path.join(target, p))}


def grade_draft_l(slug, parts, areas, target):
    """A draft on the L tree: a new SKILL.md, or add-warehouse-load's new references/project-pattern.md (no frontmatter)."""
    if 'SKILL.md' in parts:
        text, source = parts['SKILL.md']
        front, body = split_frontmatter(text)
        refs = ''.join(t for k, (t, _) in sorted(parts.items()) if k != 'SKILL.md')
    else:
        text, source = parts['references/project-pattern.md']
        front, body, refs = '', text, ''
    body_n = body.replace('\\', '/')
    every = body_n + '\n' + refs.replace('\\', '/')
    title = re.search(r'^#\s+(.+)$', body_n, re.M)
    declared = ' '.join([slug.replace('-', ' '), front, title.group(1) if title else ''])
    kinds = [k for k, rx in L_KIND_PATTERNS.items() if re.search(rx, declared, re.I)]
    components = ['dim', 'fact', 'view'] if 'area' in kinds or not kinds else [k for k in ('dim', 'fact', 'view') if k in kinds]
    listed = [a for a in areas if a in every]
    x1_only = not listed and 'usp_LoadFactSales_' in every
    loads = re.search(r'usp_LoadDim|usp_LoadFact|\bfact\.Fact|\bdim\.Dim', every)
    op = 'X1' if x1_only else ('P3' if listed or loads else 'other')
    row = {'slug': slug, 'op': op, 'source': source, 'origin': bool(re.search(r'^origin:\s*discovered\s*$', front, re.M)),
           'draftPrefix': bool(re.search(r'DRAFT, pending PR review:', front)),
           'link': bool(re.search(r'\]\((?:\./)?references/[^)\s]+\.md\)', body_n)), 'reference': any(k != 'SKILL.md' for k in parts),
           'steps': len(re.findall(r'^\s*\d+\.\s', body, re.M)), 'components': components, 'instancesListed': len(listed)}
    if op != 'P3':
        row.update({'instances': [], 'contained': [], 'named': [], 'omitted': [], 'extraFiles': []})
        return row
    graded = listed or areas
    wanted = {s for c in components for s in L_COMPONENTS[c]}
    contained = sorted({s for a in graded for s in l_area_files(target, a).values()} & wanted)
    named = sorted(s for s in contained if re.search(L_STEP_PATTERNS[s], body_n))
    row.update({'instances': listed[:6] + (['...'] if len(listed) > 6 else []), 'contained': contained, 'named': named,
                'omitted': [s for s in contained if s not in named], 'extraFiles': []})
    return row


def parent_context(events):
    """The parent session's largest prompt (input + cache read + cache creation tokens of one main-agent turn), compactions."""
    peak = 0
    for e in events:
        if e.get('type') == 'assistant' and not e.get('parent_tool_use_id'):
            u = e.get('message', {}).get('usage') or {}
            peak = max(peak, sum(int(u.get(k) or 0) for k in ('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens')))
    compactions = sum(1 for e in events if e.get('type') == 'system' and 'compact' in str(e.get('subtype', '')))
    limits = [e.get('rate_limit_info') or {} for e in events if e.get('type') == 'rate_limit_event']
    return peak, compactions, (limits[-1].get('status'), (limits[-1].get('unifiedWindows') or {}).get('five_hour', {}).get('utilization')) if limits else (None, None)


def grade_run(label, target, stream_paths, fixture='v3'):
    events = read_events(stream_paths)
    files, written, shell_writes = collect_drafts(target, events)
    owned = framework_slugs(target)
    if fixture == 'l':
        # dist/dotnet ships add-warehouse-load's SKILL.md only, so any references/project-pattern.md under it is a draft.
        areas = l_areas(target)
        drafts = [grade_draft_l(slug, parts, areas, target) for slug, parts in sorted(files.items())
                  if (slug not in owned and 'SKILL.md' in parts) or (slug == 'add-warehouse-load' and 'references/project-pattern.md' in parts)]
    else:
        drafts = [grade_draft(slug, parts) for slug, parts in sorted(files.items()) if slug not in owned and 'SKILL.md' in parts]
    results = [e for e in events if e.get('type') == 'result']
    inits = [e for e in events if e.get('type') == 'system' and e.get('subtype') == 'init']
    peak, compactions, limit = parent_context(events)
    run = {'run': label, 'drafts': len(drafts), 'P1': sum(d['op'] == 'P1' for d in drafts), 'P2': sum(d['op'] == 'P2' for d in drafts),
           'P3': sum(d['op'] == 'P3' for d in drafts), 'other': sum(d['op'] in ('other', 'X1') for d in drafts),
           'omittedTotal': sum(len(d['omitted']) for d in drafts),
           'omittedV2': sum(len([s for s in d['omitted'] if s in V2_STEPS]) for d in drafts),
           'omittedAdded': sum(len([s for s in d['omitted'] if s not in V2_STEPS]) for d in drafts),
           'draftsWithOmission': sum(bool(d['omitted']) for d in drafts),
           'frameworkSkillWrites': sorted(s for s in written if s in owned), 'shellSkillWrites': len(shell_writes),
           'calls': len(results), 'costUsd': results[-1].get('total_cost_usd') if results else None,
           'durationMs': sum(int(r.get('duration_ms') or 0) for r in results),
           'model': inits[0].get('model') if inits else None, 'ccVersion': inits[0].get('claude_code_version') if inits else None,
           'denials': sum(len(r.get('permission_denials') or []) for r in results),
           'workers': sum(1 for e in events if e.get('type') == 'assistant' for c in e.get('message', {}).get('content', []) or []
                          if c.get('type') == 'tool_use' and c.get('name') in ('Task', 'Agent')),
           'parentPeakContext': peak, 'compactions': compactions, 'rateLimit': f'{limit[0]}@{limit[1]}'}
    return run, drafts


def format_rows(run, drafts):
    lines = []
    for d in drafts:
        lines.append(f"DRAFT run={run['run']} slug={d['slug']} op={d['op']} source={d['source']} instances={','.join(d['instances']) or '-'} "
                     f"contained={len(d['contained'])} omitted={','.join(d['omitted']) or '-'} link={d['link']} reference={d['reference']} "
                     f"origin={d['origin']} draftPrefix={d['draftPrefix']} steps={d['steps']} extraFiles={','.join(d['extraFiles']) or '-'}"
                     + (f" components={','.join(d['components'])} instancesListed={d['instancesListed']}" if 'components' in d else ''))
    lines.append(' '.join(f'{k}={v}' for k, v in run.items() if k not in ('frameworkSkillWrites',)) +
                 f" frameworkSkillWrites={','.join(run['frameworkSkillWrites']) or '-'}")
    lines[-1] = 'RUN ' + lines[-1]
    return lines


# ---------------------------------------------------------------------------------------------------------------------
COMPLETE_P1 = '''---
name: add-integration-event
description: >
  DRAFT, pending PR review: add an integration event (record, handler, registry, schema, DI, test, topic).
origin: discovered
---

# Add an integration event

Derived from order-placed, order-shipped and invoice-issued; details in [the reference](references/project-pattern.md).

1. Check whether an existing event already owns the responsibility.
2. Add the record in `src/Orders.Domain/Events` implementing `IIntegrationEvent` with `[EventVersion(n)]`.
3. Add `contracts/events/<topic>.v<n>.schema.json`; its `v<n>` must equal the record's version.
4. Add the handler in `Orders.Application/EventHandlers` implementing `IIntegrationEventHandler<T>`.
5. Add `Register<TEvent, THandler>(...)` to the `EventRegistry` constructor.
6. Register the handler in `src/Orders.Api/Program.cs` with `AddScoped<THandler>()`.
7. Add the type to the `[InlineData]` rows of `EventRegistryTests`.
8. Raise it from `OrderLifecycle` through `IOutbox.Enqueue`, called from `CheckoutController`.
9. Add the topic to `infra/servicebus/topics.json`.
'''
COMPLETE_P2 = '''---
name: add-report-export
description: "DRAFT, pending PR review: add a CSV report export."
origin: discovered
---

# Add a report export

Instances: monthly-sales, open-orders, overdue-invoices ([reference](references/project-pattern.md)).

1. Add `src/Orders.Reporting/Exports/<Name>Export.cs` implementing `IReportExport`.
2. Add `db/views/rpt.vw<Name>.sql`.
3. Add `new Exports.<Name>Export()` to `ReportCatalog.All`.
4. Add `"reports.export.<key>": true` to `config/feature-flags.json`.
5. Add `GRANT SELECT ON rpt.vw<Name> TO ReportReader;` to `db/security/reporting-grants.sql`.
6. Add the key to `ReportCatalogTests`.
7. List the view in `db/deploy-order.txt` before the grants.
'''
DECOY = '''---
name: add-crud-resource
description: "DRAFT, pending PR review: add a CRUD controller."
origin: discovered
---

1. Add an entity, an EF configuration and a controller like `CustomersController.cs`.
'''


def _stream(path, writes, cost=0.5):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(json.dumps({'type': 'system', 'subtype': 'init', 'model': 'm', 'claude_code_version': 'v'}) + '\n')
        for p, content in writes:
            f.write(json.dumps({'type': 'assistant', 'message': {'content': [
                {'type': 'tool_use', 'name': 'Write', 'input': {'file_path': p, 'content': content}}]}}) + '\n')
        f.write(json.dumps({'type': 'result', 'total_cost_usd': cost, 'duration_ms': 1000, 'permission_denials': [{}] * len(writes)}) + '\n')


def self_test():
    failures, shown = [], []

    def expect(name, actual, wanted):
        if actual != wanted:
            failures.append(f'{name}: got {actual!r}, expected {wanted!r}')

    with tempfile.TemporaryDirectory() as tmp:
        target = os.path.join(tmp, 'target')
        os.makedirs(os.path.join(target, '.claude', 'skills', 'add-tests'))
        with open(os.path.join(target, 'framework-ownership.json'), 'w', encoding='utf-8') as f:
            json.dump({'paths': [{'path': '.claude/skills/add-tests/SKILL.md', 'ownership': 'framework-owned/overwritten'}]}, f)
        root = target.replace('/', '\\') + '\\.claude\\skills\\'
        no_di = COMPLETE_P1.replace('6. Register the handler in `src/Orders.Api/Program.cs` with `AddScoped<THandler>()`.\n', '')
        no_deploy = COMPLETE_P2.replace('7. List the view in `db/deploy-order.txt` before the grants.\n', '')
        # 1: complete drafts, refused Write payloads only: nothing omitted.
        s1 = os.path.join(tmp, 's1.jsonl')
        _stream(s1, [(root + 'add-integration-event\\SKILL.md', COMPLETE_P1), (root + 'add-integration-event\\references\\project-pattern.md', 'x'),
                     (root + 'add-report-export\\SKILL.md', COMPLETE_P2)])
        run, drafts = grade_run('t1', target, [s1])
        expect('complete: omitted', [d['omitted'] for d in drafts], [[], []])
        expect('complete: ops', [d['op'] for d in drafts], ['P1', 'P2'])
        expect('complete: instances', [len(d['instances']) for d in drafts], [3, 3])
        expect('complete: run', (run['drafts'], run['P1'], run['P2'], run['omittedTotal'], run['denials']), (2, 1, 1, 0, 3))
        expect('complete: link and reference', [(d['link'], d['reference']) for d in drafts], [(True, True), (True, False)])
        # 2: the hand-made drafts that omit a step: the grader must go red on each.
        s2 = os.path.join(tmp, 's2.jsonl')
        _stream(s2, [(root + 'add-integration-event\\SKILL.md', no_di), (root + 'add-report-export\\SKILL.md', no_deploy)])
        run, drafts = grade_run('t2', target, [s2])
        expect('omits DI: omitted', drafts[0]['omitted'], ['di'])
        expect('omits deploy: omitted', drafts[1]['omitted'], ['deploy'])
        expect('omission split', (run['omittedTotal'], run['omittedV2'], run['omittedAdded'], run['draftsWithOmission']), (2, 1, 1, 2))
        shown += format_rows(run, drafts)
        # 3: a step named only in the description, or a registry named only as its test class, is omitted.
        desc_only = no_di.replace('(record, handler', '(Program.cs DI, record, handler')
        no_registry = COMPLETE_P1.replace('5. Add `Register<TEvent, THandler>(...)` to the `EventRegistry` constructor.\n', '')
        s3 = os.path.join(tmp, 's3.jsonl')
        _stream(s3, [(root + 'a\\SKILL.md', desc_only), (root + 'b\\SKILL.md', no_registry)])
        run, drafts = grade_run('t3', target, [s3])
        expect('description-only DI', drafts[0]['omitted'], ['di'])
        expect('registry named only as EventRegistryTests', (drafts[1]['op'], drafts[1]['omitted']), ('P1', ['registry']))
        # 4: the file in the tree wins over the payload; the last payload wins over an earlier one; framework slugs are not drafts.
        os.makedirs(os.path.join(target, '.claude', 'skills', 'add-report-export'))
        with open(os.path.join(target, '.claude', 'skills', 'add-report-export', 'SKILL.md'), 'w', encoding='utf-8') as f:
            f.write(COMPLETE_P2)
        s4 = os.path.join(tmp, 's4.jsonl')
        _stream(s4, [(root + 'add-report-export\\SKILL.md', no_deploy), (root + 'add-integration-event\\SKILL.md', no_di),
                     (root + 'add-integration-event\\SKILL.md', COMPLETE_P1), (root + 'add-tests\\SKILL.md', 'framework')])
        run, drafts = grade_run('t4', target, [s4])
        expect('tree and last payload', [(d['slug'], d['source'], d['omitted']) for d in drafts],
               [('add-integration-event', 'payload', []), ('add-report-export', 'tree', [])])
        expect('framework skill write', run['frameworkSkillWrites'], ['add-tests'])
        # 5: a decoy draft is a false positive, graded on nothing; a listed-instance-free draft is graded on all three.
        s5 = os.path.join(tmp, 's5.jsonl')
        bare = COMPLETE_P1.replace('Derived from order-placed, order-shipped and invoice-issued; details in', 'Details in')
        _stream(s5, [(root + 'add-crud-resource\\SKILL.md', DECOY), (root + 'z\\SKILL.md', bare)])
        os.remove(os.path.join(target, '.claude', 'skills', 'add-report-export', 'SKILL.md'))
        run, drafts = grade_run('t5', target, [s5])
        expect('decoy', (run['other'], drafts[0]['op']), (1, 'other'))
        expect('no instance listed', (drafts[1]['instancesListed'], len(drafts[1]['contained'])), (0, 8))
        # 6: the ground truth is the fixture's history.
        repo = os.path.join(tmp, 'fixture')
        cwd = os.getcwd()
        try:
            _gen.generate(repo)
            expect('history matches INSTANCE_FILES', _gen.check(repo), [])
        finally:
            os.chdir(cwd)
        # 7 (--fixture l): two areas named as Get-WarehouseScaleArea names them, the base job and one X1 loader.
        ltarget = os.path.join(tmp, 'l')
        for p in L_AREA_TREE:
            os.makedirs(os.path.dirname(os.path.join(ltarget, p)), exist_ok=True)
            with open(os.path.join(ltarget, p), 'w', encoding='utf-8') as f:
                f.write('--\n')
        lroot = ltarget.replace('/', '\\') + '\\.claude\\skills\\'
        expect('l areas', l_areas(ltarget), ['CardFacility', 'PayrollOverdraft'])
        expect('l area files', sorted(l_area_files(ltarget, 'PayrollOverdraft')), sorted(p for p in L_AREA_TREE if 'PayrollOverdraft' in p))
        no_job = COMPLETE_L.replace('8. Add `Jobs/<Area>Daily.sql`: one `sp_add_jobstep` per loader, dimensions before facts.\n', '')
        fact_only = COMPLETE_L.replace('name: add-subject-area', 'name: add-fact-load').replace(
            'add a warehouse subject area (staging, dimensions, facts, loaders, views, job)', 'add a fact load').replace('# Add a subject area', '# Add a fact load')
        fact_only_no_job = fact_only.replace('8. Add `Jobs/<Area>Daily.sql`: one `sp_add_jobstep` per loader, dimensions before facts.\n', '')
        s7 = os.path.join(tmp, 's7.jsonl')
        _stream(s7, [(lroot + 'add-subject-area\\SKILL.md', COMPLETE_L), (lroot + 'no-job\\SKILL.md', no_job),
                     (lroot + 'add-fact-load\\SKILL.md', fact_only_no_job), (lroot + 'add-warehouse-load\\references\\project-pattern.md', REFERENCE_L),
                     (lroot + 'sales-variants\\SKILL.md', X1_DECOY)])
        run, drafts = grade_run('l7', ltarget, [s7], fixture='l')
        got = {d['slug']: (d['op'], d['components'], d['contained'], d['omitted']) for d in drafts}
        everything = ['dimension', 'dimload', 'fact', 'factload', 'job', 'staging', 'view']
        expect('l complete', got.get('add-subject-area'), ('P3', ['dim', 'fact', 'view'], everything, []))
        expect('l omits the job', got.get('no-job'), ('P3', ['dim', 'fact', 'view'], everything, ['job']))
        expect('l fact load omits the job', got.get('add-fact-load'), ('P3', ['fact'], ['fact', 'factload', 'job', 'staging'], ['job']))
        expect('l add-warehouse-load reference', got.get('add-warehouse-load'),
               ('P3', ['dim', 'fact'], ['dimension', 'dimload', 'fact', 'factload', 'job', 'staging'], []))
        expect('l X1 decoy', got.get('sales-variants', ('?',))[0], 'X1')
        expect('l run', (run['drafts'], run['P3'], run['other'], run['omittedTotal'], run['draftsWithOmission']), (5, 4, 1, 2, 2))
        shown += [r for r in format_rows(run, drafts) if 'no-job' in r or 'add-fact-load' in r]
    return failures, shown


L_AREA_TREE = ['Jobs/NightlyCore.sql', 'StoredProcedures/usp_LoadFactSales_v2.sql',
               'Tables/stg.StgPayrollOverdraftSnapshot.sql', 'Tables/stg.StgPayrollOverdraftEvent.sql', 'Tables/dim.DimPayrollOverdraft.sql',
               'Tables/dim.DimPayrollOverdraftSegment.sql', 'Tables/dim.DimPayrollOverdraftStatus.sql', 'Tables/fact.FactPayrollOverdraftSnapshot.sql',
               'Tables/fact.FactPayrollOverdraftEvent.sql', 'StoredProcedures/usp_LoadDimPayrollOverdraft.sql',
               'StoredProcedures/usp_LoadDimPayrollOverdraftSegment.sql', 'StoredProcedures/usp_LoadDimPayrollOverdraftStatus.sql',
               'StoredProcedures/usp_LoadFactPayrollOverdraftSnapshot.sql', 'StoredProcedures/usp_LoadFactPayrollOverdraftEvent.sql',
               'Views/rpt.vwPayrollOverdraftByMonth.sql', 'Jobs/PayrollOverdraftDaily.sql',
               'Tables/stg.StgCardFacilityMovement.sql', 'Tables/dim.DimCardFacility.sql', 'Tables/fact.FactCardFacilityMovement.sql',
               'StoredProcedures/usp_LoadDimCardFacility.sql', 'StoredProcedures/usp_LoadFactCardFacilityMovement.sql',
               'Views/rpt.vwCardFacilitySummary.sql', 'Jobs/CardFacilityDaily.sql']
COMPLETE_L = '''---
name: add-subject-area
description: >
  DRAFT, pending PR review: add a warehouse subject area (staging, dimensions, facts, loaders, views, job).
origin: discovered
---

# Add a subject area

Instances: PayrollOverdraft, CardFacility ([reference](references/project-pattern.md)).

1. Check whether an existing subject area already owns the data.
2. Add `Tables/stg.Stg<Area><Kind>.sql` with `BatchId`.
3. Add `Tables/dim.Dim<Area>.sql` and any `dim.Dim<Area><Kind>` lookup dimensions.
4. Add `Tables/fact.Fact<Area><Kind>.sql` with `LoadRunId`.
5. Add `usp_LoadDim<Area>`, and one per lookup dimension.
6. Add `usp_LoadFact<Area><Kind>`, stamping `LoadRunId` from the staging `BatchId`.
7. Add `Views/rpt.vw<Area><View>.sql`.
8. Add `Jobs/<Area>Daily.sql`: one `sp_add_jobstep` per loader, dimensions before facts.
'''
REFERENCE_L = '''# Project pattern: dimension and fact loads (draft, pending PR review)

Instances: `usp_LoadFactPayrollOverdraftSnapshot`, `usp_LoadFactCardFacilityMovement`, `usp_LoadDimCardFacility`.

1. Stage rows in `stg.Stg<Area><Kind>` with `BatchId`.
2. Load `dim.Dim<Area>` with `usp_LoadDim<Area>` (MERGE on the business id).
3. Load `fact.Fact<Area><Kind>` with `usp_LoadFact<Area><Kind>`, `LoadRunId` from `BatchId`.
4. Add each loader as a step of `Jobs/<Area>Daily.sql`, dimensions first.
'''
X1_DECOY = '''---
name: sales-variants
description: "DRAFT, pending PR review: add a sales fact loader variant."
origin: discovered
---

Instances: `usp_LoadFactSales_v2`, `usp_LoadFactSales_v3`, `usp_LoadFactSales_Audited`.

1. Copy `usp_LoadFactSales` and open a `ctl.LoadRun` row.
'''


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    if sys.argv[1:] == ['--self-test']:
        failures, shown = self_test()
        print('\n'.join(shown))
        if failures:
            print('\n'.join('SELF-TEST FAIL: ' + f for f in failures))
            sys.exit(1)
        print('SELF-TEST PASS: the hand-made drafts that omit a step read omitted=di, omitted=deploy and (L) omitted=job (above); '
              'complete drafts read none')
        sys.exit(0)
    args = sys.argv[1:]
    out, fixture = None, 'v3'
    if '--json' in args:
        i = args.index('--json')
        out = args[i + 1]
        del args[i:i + 2]
    if '--fixture' in args:
        i = args.index('--fixture')
        fixture = args[i + 1]
        del args[i:i + 2]
    if len(args) < 3:
        sys.exit(__doc__)
    if fixture not in ('v3', 'l'):
        sys.exit(f'--fixture {fixture}: expected v3 or l')
    run, drafts = grade_run(args[0], args[1], args[2:], fixture)
    print('\n'.join(format_rows(run, drafts)))
    if out:
        with open(out, 'w', encoding='utf-8') as f:
            json.dump({'run': run, 'drafts': drafts}, f, indent=2)
