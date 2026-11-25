import { expect, Page } from '@playwright/test';

export class ShopPage {
  constructor(private readonly page: Page) {}

  async open(): Promise<void> {
    await this.page.goto('/');
    await expect(this.page.getByRole('heading', { name: 'Products' })).toBeVisible();
  }

  async addToCart(productName: string): Promise<void> {
    await this.page
      .getByRole('listitem')
      .filter({ hasText: productName })
      .getByRole('button', { name: 'Add to cart' })
      .click();
  }

  async openCart(): Promise<void> {
    await this.page.getByRole('link', { name: 'Cart', exact: true }).click();
    await expect(this.page.getByRole('heading', { name: 'Your cart' })).toBeVisible();
  }

  async expectInCart(productName: string): Promise<void> {
    await expect(
      this.page.getByRole('list', { name: 'Cart items' }).getByText(productName),
    ).toBeVisible();
  }

  async startCheckout(): Promise<void> {
    await this.page.getByRole('link', { name: 'Checkout' }).click();
    await expect(this.page.getByRole('heading', { name: 'Checkout' })).toBeVisible();
  }
}
