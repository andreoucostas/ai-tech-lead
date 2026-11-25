import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-confirmation-page',
  template: `
    <h2>Order placed</h2>
    <p>Your order number is {{ id }}.</p>
  `,
})
export class ConfirmationPage {
  protected readonly id = inject(ActivatedRoute).snapshot.paramMap.get('id');
}
