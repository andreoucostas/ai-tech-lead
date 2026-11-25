import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { CartStore } from './cart.store';
import { CheckoutPage } from './checkout.page';
import { PRODUCTS } from './products.data';

describe('CheckoutPage', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CartStore, provideRouter([]), provideHttpClient(), provideHttpClientTesting()],
    });
  });

  it('summarises the cart items', async () => {
    TestBed.inject(CartStore).add(PRODUCTS[0]);
    const fixture = TestBed.createComponent(CheckoutPage);
    await fixture.whenStable();

    expect((fixture.nativeElement as HTMLElement).textContent).toContain('Blue mug');
  });

  it('shows "Enter a valid email" for an invalid email', async () => {
    const fixture = TestBed.createComponent(CheckoutPage);
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    const email = element.querySelector<HTMLInputElement>('#email');

    email!.value = 'not-an-email';
    email!.dispatchEvent(new Event('input'));
    email!.dispatchEvent(new Event('blur'));
    await fixture.whenStable();

    expect(element.textContent).toContain('Enter a valid email');
  });
});
