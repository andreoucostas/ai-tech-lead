import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { CartStore } from './cart.store';
import { OrderService } from './order.service';

@Component({
  selector: 'app-checkout-page',
  imports: [ReactiveFormsModule],
  template: `
    <h2>Checkout</h2>
    <section aria-labelledby="summary-heading">
      <h3 id="summary-heading">Order summary</h3>
      <ul>
        @for (item of cart.items(); track item.product.id) {
          <li>{{ item.product.name }} x {{ item.quantity }}</li>
        }
      </ul>
      <p>Total {{ cart.total().toFixed(2) }}</p>
    </section>
    <form [formGroup]="form" (ngSubmit)="submit()">
      <label for="name">Name</label>
      <input id="name" formControlName="name" />
      <label for="email">Email</label>
      <input id="email" type="email" formControlName="email" />
      @if (form.controls.email.invalid && form.controls.email.touched) {
        <p role="alert">Enter a valid email</p>
      }
      <label for="address">Address</label>
      <input id="address" formControlName="address" />
      <button type="submit" [disabled]="form.invalid">Place order</button>
    </form>
    @if (failed()) {
      <p role="alert">The order could not be placed.</p>
    }
  `,
})
export class CheckoutPage {
  protected readonly cart = inject(CartStore);
  private readonly orders = inject(OrderService);
  private readonly router = inject(Router);

  protected readonly failed = signal(false);
  protected readonly form = inject(FormBuilder).nonNullable.group({
    name: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
    address: ['', Validators.required],
  });

  protected submit(): void {
    if (this.form.invalid) {
      return;
    }
    this.failed.set(false);
    const lines = this.cart.items().map((item) => ({
      productId: item.product.id,
      quantity: item.quantity,
    }));
    this.orders.place({ customer: this.form.getRawValue(), lines }).subscribe({
      next: ({ id }) => {
        this.cart.clear();
        void this.router.navigate(['/confirmation', id]);
      },
      error: () => this.failed.set(true),
    });
  }
}
