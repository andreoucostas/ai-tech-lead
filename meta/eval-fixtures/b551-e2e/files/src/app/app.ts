import { Component } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  imports: [RouterLink, RouterOutlet],
  template: `
    <header>
      <h1>Shop</h1>
      <nav aria-label="Main">
        <a routerLink="/">Products</a>
        <a routerLink="/cart">Cart</a>
        <a routerLink="/help">Help</a>
      </nav>
    </header>
    <main>
      <router-outlet />
    </main>
  `,
})
export class App {}
