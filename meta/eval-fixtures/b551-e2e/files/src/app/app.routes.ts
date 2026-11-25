import { Routes } from '@angular/router';
import { CartPage } from './cart.page';
import { CheckoutPage } from './checkout.page';
import { ConfirmationPage } from './confirmation.page';
import { HelpPage } from './help.page';
import { ProductsPage } from './products.page';

export const routes: Routes = [
  { path: '', component: ProductsPage },
  { path: 'cart', component: CartPage },
  { path: 'checkout', component: CheckoutPage },
  { path: 'confirmation/:id', component: ConfirmationPage },
  { path: 'help', component: HelpPage },
];
