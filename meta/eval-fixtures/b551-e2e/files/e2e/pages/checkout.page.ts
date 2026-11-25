import { expect, Page } from '@playwright/test';

export interface Customer {
  name: string;
  email: string;
  address: string;
}

export class CheckoutPage {
  constructor(private readonly page: Page) {}

  async expectSummaryItem(productName: string): Promise<void> {
    await expect(
      this.page.getByRole('region', { name: 'Order summary' }).getByText(productName),
    ).toBeVisible();
  }

  async fillCustomer(customer: Customer): Promise<void> {
    await this.page.getByLabel('Name').fill(customer.name);
    await this.page.getByLabel('Email').fill(customer.email);
    await this.page.getByLabel('Address').fill(customer.address);
  }

  async placeOrder(): Promise<void> {
    await this.page.getByRole('button', { name: 'Place order' }).click();
  }

  async expectConfirmed(): Promise<void> {
    await expect(this.page.getByRole('heading', { name: 'Order placed' })).toBeVisible();
  }
}
