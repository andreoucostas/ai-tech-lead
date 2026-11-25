export interface Product {
  id: number;
  name: string;
  price: number;
}

export const PRODUCTS: Product[] = [
  { id: 1, name: 'Blue mug', price: 8.5 },
  { id: 2, name: 'Red notebook', price: 4 },
  { id: 3, name: 'Green pen', price: 1.5 },
];
