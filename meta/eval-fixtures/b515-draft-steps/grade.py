"""B-515 grader: for each project-skill draft one headless /bootstrap composed on fixture v3, the steps its own listed
instances contain that the draft omits, counted from the instances' files (generate.py's INSTANCE_FILES, which
`generate.py --check` ties to the fixture's history).

    python grade.py <run label> <target> <stream.jsonl> [<stream.jsonl> ...] [--json <out.json>]
    python grade.py --self-test

A draft is a new .claude/skills/<slug>/SKILL.md (a slug framework-ownership.json does not own): the file in the target
when the write landed, else the last Write payload for that path in the streams (this host refuses writes under
.claude/skills/ in acceptEdits, B-514). Its references/*.md are read the same way. A step counts as named when its
pattern matches the SKILL.md body (frontmatter excluded): a step only the description or the reference names is
omitted. The grader never reads the agent's final message.
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


def grade_run(label, target, stream_paths):
    events = read_events(stream_paths)
    files, written, shell_writes = collect_drafts(target, events)
    owned = framework_slugs(target)
    drafts = [grade_draft(slug, parts) for slug, parts in sorted(files.items()) if slug not in owned and 'SKILL.md' in parts]
    results = [e for e in events if e.get('type') == 'result']
    inits = [e for e in events if e.get('type') == 'system' and e.get('subtype') == 'init']
    run = {'run': label, 'drafts': len(drafts), 'P1': sum(d['op'] == 'P1' for d in drafts), 'P2': sum(d['op'] == 'P2' for d in drafts),
           'other': sum(d['op'] == 'other' for d in drafts),
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
                          if c.get('type') == 'tool_use' and c.get('name') in ('Task', 'Agent'))}
    return run, drafts


def format_rows(run, drafts):
    lines = []
    for d in drafts:
        lines.append(f"DRAFT run={run['run']} slug={d['slug']} op={d['op']} source={d['source']} instances={','.join(d['instances']) or '-'} "
                     f"contained={len(d['contained'])} omitted={','.join(d['omitted']) or '-'} link={d['link']} reference={d['reference']} "
                     f"origin={d['origin']} draftPrefix={d['draftPrefix']} steps={d['steps']} extraFiles={','.join(d['extraFiles']) or '-'}")
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
    return failures, shown


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    if sys.argv[1:] == ['--self-test']:
        failures, shown = self_test()
        print('\n'.join(shown))
        if failures:
            print('\n'.join('SELF-TEST FAIL: ' + f for f in failures))
            sys.exit(1)
        print('SELF-TEST PASS: the hand-made drafts that omit a step read omitted=di and omitted=deploy (above); complete drafts read none')
        sys.exit(0)
    args = sys.argv[1:]
    out = None
    if '--json' in args:
        i = args.index('--json')
        out = args[i + 1]
        del args[i:i + 2]
    if len(args) < 3:
        sys.exit(__doc__)
    run, drafts = grade_run(args[0], args[1], args[2:])
    print('\n'.join(format_rows(run, drafts)))
    if out:
        with open(out, 'w', encoding='utf-8') as f:
            json.dump({'run': run, 'drafts': drafts}, f, indent=2)
