import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    flash_sale: {
      executor: 'constant-arrival-rate',
      rate: 10,
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 5,
      maxVUs: 50,
    },
  },
};

export default function () {
  const url = 'http://redemption-api-internal.deduction.svc.cluster.local:8080/redeem';
  
  const randomUserId = Math.floor(Math.random() * 100) + 1;
  const targetEmail = `user${randomUserId}@example.com`;

  const payload = JSON.stringify({ 
    email: targetEmail, 
    amount: 500 
  });
  
  const params = { headers: { 'Content-Type': 'application/json' } };
  
  const res = http.post(url, payload, params);
  
  check(res, {
    'status is 200/202': (r) => r.status === 200 || r.status === 202,
  });
}