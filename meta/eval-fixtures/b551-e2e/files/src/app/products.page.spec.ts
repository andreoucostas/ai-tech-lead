import { TestBed } from '@angular/core/testing';
import { CartStore } from './cart.store';
import { ProductsPage } from './products.page';

describe('ProductsPage', () => {
  it('lists the products and adds one to the cart', async () => {
    TestBed.configureTestingModule({ providers: [CartStore] });
    const fixture = TestBed.createComponent(ProductsPage);
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;

    expect(element.textContent).toContain('Blue mug');

    element.querySelector('button')?.click();

    expect(TestBed.inject(CartStore).count()).toBe(1);
  });
});
