import { TestBed } from '@angular/core/testing';
import { CartStore } from './cart.store';
import { PRODUCTS } from './products.data';

describe('CartStore', () => {
  let store: CartStore;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [CartStore] });
    store = TestBed.inject(CartStore);
  });

  it('starts empty', () => {
    expect(store.items()).toEqual([]);
    expect(store.count()).toBe(0);
  });

  it('adds a product and counts repeats', () => {
    store.add(PRODUCTS[0]);
    store.add(PRODUCTS[0]);
    store.add(PRODUCTS[1]);

    expect(store.items().length).toBe(2);
    expect(store.count()).toBe(3);
    expect(store.total()).toBe(8.5 * 2 + 4);
  });

  it('clears the cart', () => {
    store.add(PRODUCTS[0]);
    store.clear();

    expect(store.items()).toEqual([]);
  });
});
