import { expect, test } from './fixtures';

test('the products page lists the products', async ({ page, shop }) => {
  await shop.open();

  await expect(page.getByRole('listitem').filter({ hasText: 'Blue mug' })).toBeVisible();
  await expect(page.getByRole('listitem').filter({ hasText: 'Green pen' })).toBeVisible();
});

test('the help page opens from the navigation', async ({ page, shop }) => {
  await shop.open();
  await page.getByRole('link', { name: 'Help' }).click();

  await expect(page.getByRole('heading', { name: 'Help' })).toBeVisible();
});

test('an empty cart says so', async ({ page, shop }) => {
  await shop.open();
  await shop.openCart();

  await expect(page.getByText('Your cart is empty.')).toBeVisible();
});
