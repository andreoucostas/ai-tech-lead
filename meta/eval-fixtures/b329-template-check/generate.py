# B-329 fixture (meta only; never shipped). An Angular 21.1.2 workspace of N standalone components in features of 20, each
# with signal inputs, an output, an injected per-feature signal service and an external template of about 20 lines; a shell
# component per feature renders its components and lazy routes load the shells. Deterministic, UTF-8, LF.
# Usage: python generate.py --components N --out DIR
import argparse, json, os, sys

parser = argparse.ArgumentParser()
parser.add_argument('--components', type=int, required=True)
parser.add_argument('--out', required=True)
opts = parser.parse_args()
if opts.components < 3:
    sys.exit('refusing: --components must be at least 3')
if os.path.isdir(opts.out) and os.listdir(opts.out):
    sys.exit(f'refusing: {opts.out} is not empty')
os.makedirs(opts.out, exist_ok=True)
os.chdir(opts.out)


def w(p, s):
    os.makedirs(os.path.dirname(p) or '.', exist_ok=True)
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        f.write(s.lstrip('\n'))


def fill(text, **tokens):
    for k, v in tokens.items():
        text = text.replace('@@' + k + '@@', v)
    return text


ANGULAR = '21.1.2'
w('package.json', json.dumps({
    'name': 'b329-workspace', 'version': '0.0.0', 'private': True,
    'dependencies': {**{f'@angular/{p}': ANGULAR for p in ('common', 'compiler', 'core', 'forms', 'platform-browser', 'router')},
                     'rxjs': '7.8.2', 'tslib': '2.8.1'},
    'devDependencies': {'@angular/compiler-cli': ANGULAR, 'typescript': '5.9.3', 'semver': '7.7.4'},
}, indent=2) + '\n')
w('tsconfig.json', json.dumps({
    'compileOnSave': False,
    'compilerOptions': {
        'strict': True, 'noImplicitOverride': True, 'noPropertyAccessFromIndexSignature': True, 'noImplicitReturns': True,
        'noFallthroughCasesInSwitch': True, 'skipLibCheck': True, 'isolatedModules': True, 'experimentalDecorators': True,
        'importHelpers': True, 'target': 'ES2022', 'module': 'preserve'},
    'angularCompilerOptions': {
        'enableI18nLegacyMessageIdFormat': False, 'strictInjectionParameters': True, 'strictInputAccessModifiers': True,
        'strictTemplates': True},
    'files': [],
    'references': [{'path': './tsconfig.app.json'}],
}, indent=2) + '\n')
w('tsconfig.app.json', json.dumps({
    'extends': './tsconfig.json',
    'compilerOptions': {'outDir': './out-tsc/app', 'types': []},
    'include': ['src/**/*.ts'],
    'exclude': ['src/**/*.spec.ts'],
}, indent=2) + '\n')

n = opts.components
features = [(f, min(20, n - 20 * (f - 1))) for f in range(1, (n + 19) // 20 + 1)]
fid = lambda f: f'f{f:02d}'
cid = lambda m: f'c{m:02d}'
cls = lambda f, m: f'F{f:02d}C{m:02d}Component'

w('src/main.ts', '''
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';

bootstrapApplication(AppComponent, { providers: [provideRouter(routes)] }).catch(err => console.error(err));
''')
w('src/app/shared/models.ts', '''
export interface Item {
  id: number;
  name: string;
  price: number;
  createdAt: Date;
  tags: string[];
  active: boolean;
}
''')
w('src/app/app.component.ts', fill('''
import { Component } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

@Component({
  selector: 'b329-root',
  imports: [RouterLink, RouterOutlet],
  templateUrl: './app.component.html',
})
export class AppComponent {
  protected readonly features = [@@FEATURES@@];
}
''', FEATURES=', '.join(f"'{fid(f)}'" for f, _ in features)))
w('src/app/app.component.html', '''
<nav>
  @for (feature of features; track feature) {
    <a [routerLink]="['/', feature]">{{ feature }}</a>
  }
</nav>
<router-outlet />
''')
w('src/app/app.routes.ts', '''
import { Routes } from '@angular/router';

export const routes: Routes = [
''' + ''.join(f"  {{ path: '{fid(f)}', loadComponent: () => import('./features/{fid(f)}/{fid(f)}-shell.component').then(m => m.F{f:02d}ShellComponent) }},\n"
              for f, _ in features) + f'''  {{ path: '', pathMatch: 'full', redirectTo: '{fid(1)}' }},
];
''')

SERVICE = '''
import { Injectable, computed, signal } from '@angular/core';
import { Item } from '../../shared/models';

@Injectable({ providedIn: 'root' })
export class @@SVC@@ {
  private readonly state = signal<Item[]>([]);
  readonly items = this.state.asReadonly();
  readonly count = computed(() => this.state().length);

  load(items: Item[]): void {
    this.state.set(items);
  }

  touch(id: number): void {
    this.state.update(list => list.map(item => (item.id === id ? { ...item, active: !item.active } : item)));
  }
}
'''
SHELL_TS = '''
import { Component, inject } from '@angular/core';
import { @@SVC@@ } from './@@F@@-data.service';
@@IMPORTS@@
@Component({
  selector: 'b329-@@F@@-shell',
  imports: [@@CLASSES@@],
  templateUrl: './@@F@@-shell.component.html',
})
export class @@SHELL@@ {
  protected readonly data = inject(@@SVC@@);
}
'''
COMPONENT_TS = '''
import { Component, computed, inject, input, output, signal } from '@angular/core';
import { CurrencyPipe, DatePipe, UpperCasePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Item } from '../../../shared/models';
import { @@SVC@@ } from '../@@F@@-data.service';
@@CHILD_IMPORT@@
@Component({
  selector: 'b329-@@F@@-@@C@@',
  imports: [CurrencyPipe, DatePipe, UpperCasePipe, FormsModule@@CHILD_CLASS@@],
  templateUrl: './@@F@@-@@C@@.component.html',
})
export class @@CLS@@ {
  readonly title = input.required<string>();
  readonly items = input<Item[]>([]);
  readonly selected = output<Item>();
  private readonly data = inject(@@SVC@@);
  protected readonly filter = signal('');
  protected readonly visible = computed(() => {
    const term = this.filter().toLowerCase();
    return this.items().filter(item => item.name.toLowerCase().includes(term));
  });
  protected readonly total = computed(() => this.visible().reduce((sum, item) => sum + item.price, 0));

  protected select(item: Item): void {
    this.data.touch(item.id);
    this.selected.emit(item);
  }
}
'''
COMPONENT_HTML = '''
<h2>{{ title() | uppercase }}</h2>
<input [(ngModel)]="filter" />
@if (visible().length > 0) {
  <ul>
    @for (item of visible(); track item.id) {
      <li [class.inactive]="!item.active" (click)="select(item)">
        <span>{{ item.name }}</span>
        <span>{{ item.price | currency }}</span>
        <span>{{ item.createdAt | date: 'shortDate' }}</span>
        @for (tag of item.tags; track tag) {
          <em>{{ tag }}</em>
        }
      </li>
    }
  </ul>
  <p>Total: {{ total() | currency }}</p>
} @else {
  <p>No items match.</p>
}
@@CHILD@@'''

for f, count in features:
    F, svc, shell = fid(f), f'F{f:02d}DataService', f'F{f:02d}ShellComponent'
    w(f'src/app/features/{F}/{F}-data.service.ts', fill(SERVICE, SVC=svc))
    w(f'src/app/features/{F}/{F}-shell.component.ts', fill(SHELL_TS, SVC=svc, F=F, SHELL=shell,
      IMPORTS=''.join(f"import {{ {cls(f, m)} }} from './{cid(m)}/{F}-{cid(m)}.component';\n" for m in range(1, count + 1)),
      CLASSES=', '.join(cls(f, m) for m in range(1, count + 1))))
    w(f'src/app/features/{F}/{F}-shell.component.html', ''.join(
      f'<b329-{F}-{cid(m)} title="Panel {m}" [items]="data.items()" (selected)="data.touch($event.id)" />\n' for m in range(1, count + 1)))
    for m in range(1, count + 1):
        C = cid(m)
        prev = m - 1
        w(f'src/app/features/{F}/{C}/{F}-{C}.component.ts', fill(COMPONENT_TS, SVC=svc, F=F, C=C, CLS=cls(f, m),
          CHILD_IMPORT=f"import {{ {cls(f, prev)} }} from '../{cid(prev)}/{F}-{cid(prev)}.component';\n" if prev else '',
          CHILD_CLASS=f', {cls(f, prev)}' if prev else ''))
        w(f'src/app/features/{F}/{C}/{F}-{C}.component.html', fill(COMPONENT_HTML,
          CHILD=f'<b329-{F}-{cid(prev)} [title]="title() + \' / {prev}\'" [items]="visible()" (selected)="select($event)" />\n' if prev else ''))

print('components:', n, 'features:', len(features))
