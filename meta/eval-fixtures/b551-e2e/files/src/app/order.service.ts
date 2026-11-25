import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';

export interface OrderRequest {
  customer: { name: string; email: string; address: string };
  lines: { productId: number; quantity: number }[];
}

@Injectable({ providedIn: 'root' })
export class OrderService {
  private readonly http = inject(HttpClient);

  place(order: OrderRequest): Observable<{ id: number }> {
    return this.http.post<{ id: number }>('/api/orders', order);
  }
}
