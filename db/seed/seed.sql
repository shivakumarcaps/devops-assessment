INSERT INTO hotel_bookings
  (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
  gen_random_uuid(),
  (ARRAY['11111111-1111-1111-1111-111111111111',
         '22222222-2222-2222-2222-222222222222',
         '33333333-3333-3333-3333-333333333333']::uuid[])[1 + (g % 3)],
  'HOTEL_' || (1 + g % 10),
  (ARRAY['delhi','mumbai','bengaluru','hyderabad','chennai'])[1 + (g % 5)],
  CURRENT_DATE + (g % 30),
  CURRENT_DATE + (g % 30) + 1 + (g % 4),
  round((2000 + random() * 18000)::numeric, 2),
  (ARRAY['confirmed','cancelled','pending','completed'])[1 + (g % 4)],
  NOW() - (g % 60) * INTERVAL '1 day'
FROM generate_series(1, 2000) AS g;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'booking_created',
       jsonb_build_object('source', 'web', 'amount', amount),
       created_at
FROM hotel_bookings;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'booking_confirmed',
       jsonb_build_object('status', status),
       created_at + INTERVAL '5 minutes'
FROM hotel_bookings
WHERE status IN ('confirmed', 'completed');
