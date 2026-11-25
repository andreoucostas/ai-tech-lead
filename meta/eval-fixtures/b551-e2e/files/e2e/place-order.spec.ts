import { test } from './fixtures';

test('a shopper places an order for a mug', async ({ shop, checkout }) => {
  await shop.open();
  await shop.addToCart('Blue mug');

  await shop.openCart();
  await shop.expectInCart('Blue mug');

  await shop.startCheckout();
  await checkout.expectSummaryItem('Blue mug');
  await checkout.fillCustomer({
    name: 'Ada Lovelace',
    email: 'ada@example.test',
    address: '1 Main Street',
  });
  await checkout.placeOrder();

  await checkout.expectConfirmed();
});
