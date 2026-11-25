import { test as base } from '@playwright/test';
import { CheckoutPage } from './pages/checkout.page';
import { ShopPage } from './pages/shop.page';

export const test = base.extend<{ shop: ShopPage; checkout: CheckoutPage }>({
  shop: async ({ page }, use) => {
    await use(new ShopPage(page));
  },
  checkout: async ({ page }, use) => {
    await use(new CheckoutPage(page));
  },
});

export { expect } from '@playwright/test';
