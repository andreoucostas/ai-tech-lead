# Pricing requirements

## Rounding

- FR-1: A price is rounded to the cent, with halves rounded away from zero (2.665 becomes 2.67). Banker's rounding is not used.

## Volume discount

- FR-2: An order of 10 or more units gets 5% off the subtotal. The volume discount is applied before any coupon.

## Coupons

- FR-3: A coupon is optional. Coupon codes are case-insensitive and surrounding whitespace is ignored.
- FR-4: An order with no coupon, or with a code that is not recognised, gets no coupon discount.
