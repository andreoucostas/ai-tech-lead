import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { OrderRequest, OrderService } from './order.service';

describe('OrderService', () => {
  it('posts the order to /api/orders and returns the id', () => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    const service = TestBed.inject(OrderService);
    const http = TestBed.inject(HttpTestingController);
    const order: OrderRequest = {
      customer: { name: 'Ada', email: 'ada@example.test', address: '1 Main Street' },
      lines: [{ productId: 1, quantity: 2 }],
    };

    let id: number | undefined;
    service.place(order).subscribe((result) => (id = result.id));

    const request = http.expectOne('/api/orders');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual(order);
    request.flush({ id: 7 });

    expect(id).toBe(7);
    http.verify();
  });
});
