import { computed, Injectable, signal } from '@angular/core';
import { Product } from './products.data';

export interface CartItem {
  product: Product;
  quantity: number;
}

@Injectable({ providedIn: 'root' })
export class CartStore {
  private readonly state = signal<CartItem[]>([]);

  readonly items = this.state.asReadonly();
  readonly count = computed(() => this.state().reduce((sum, item) => sum + item.quantity, 0));
  readonly total = computed(() =>
    this.state().reduce((sum, item) => sum + item.product.price * item.quantity, 0),
  );

  add(product: Product): void {
    this.state.update((items) => {
      const existing = items.find((item) => item.product.id === product.id);
      if (!existing) {
        return [...items, { product, quantity: 1 }];
      }
      return items.map((item) =>
        item.product.id === product.id ? { ...item, quantity: item.quantity + 1 } : item,
      );
    });
  }

  clear(): void {
    this.state.set([]);
  }
}
