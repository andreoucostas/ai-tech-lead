import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { CartStore } from './cart.store';

@Component({
  selector: 'app-cart-page',
  imports: [RouterLink],
  template: `
    <h2>Your cart</h2>
    @if (cart.items().length === 0) {
      <p>Your cart is empty.</p>
    } @else {
      <ul aria-label="Cart items">
        @for (item of cart.items(); track item.product.id) {
          <li>{{ item.product.name }} x {{ item.quantity }}</li>
        }
      </ul>
      <p>Total {{ cart.total().toFixed(2) }}</p>
      <a routerLink="/checkout">Checkout</a>
    }
  `,
})
export class CartPage {
  protected readonly cart = inject(CartStore);
}
