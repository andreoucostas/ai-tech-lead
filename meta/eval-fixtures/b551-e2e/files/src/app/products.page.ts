import { Component, inject } from '@angular/core';
import { CartStore } from './cart.store';
import { PRODUCTS } from './products.data';

@Component({
  selector: 'app-products-page',
  template: `
    <h2>Products</h2>
    <ul>
      @for (product of products; track product.id) {
        <li>
          <span>{{ product.name }}</span>
          <span>{{ product.price.toFixed(2) }}</span>
          <button type="button" (click)="cart.add(product)">Add to cart</button>
        </li>
      }
    </ul>
  `,
})
export class ProductsPage {
  protected readonly cart = inject(CartStore);
  protected readonly products = PRODUCTS;
}
