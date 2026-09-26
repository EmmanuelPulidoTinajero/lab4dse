const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 2,
  idleTimeoutMillis: 5000,
  ssl: { rejectUnauthorized: false },
});

const ORDER_DETAIL_QUERY = `
  SELECT
    o.id AS order_id, o.status, o.created_at,
    c.name AS customer_name, c.city,
    p.name AS product_name, p.category,
    oi.quantity, oi.unit_price,
    COALESCE(AVG(r.rating), 0) AS avg_rating,
    COUNT(r.id) AS review_count
  FROM orders o
  JOIN customers c ON c.id = o.customer_id
  JOIN order_items oi ON oi.order_id = o.id
  JOIN products p ON p.id = oi.product_id
  LEFT JOIN reviews r ON r.product_id = p.id
  WHERE o.id = $1
  GROUP BY o.id, c.name, c.city, p.name, p.category, oi.quantity, oi.unit_price
  ORDER BY o.created_at DESC
`;

function response(statusCode, bodyObj) {
  return {
    statusCode,
    statusDescription: statusCode === 200 ? '200 OK' : String(statusCode),
    isBase64Encoded: false,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(bodyObj),
  };
}

exports.handler = async (event) => {
  const path = event.path || '/';
  const method = event.httpMethod || 'GET';

  if (path === '/direct/health') {
    return response(200, { status: 'ok' });
  }

  try {
    if (method === 'POST' && path === '/direct/item') {
      const body = JSON.parse(event.body || '{}');
      const { rows: orderRows } = await pool.query(
        'INSERT INTO orders (customer_id, status) VALUES ($1, $2) RETURNING id',
        [body.customerId, body.status || 'pending']
      );
      const orderId = orderRows[0].id;
      await pool.query(
        'INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES ($1, $2, $3, $4)',
        [orderId, body.productId, body.quantity, body.unitPrice]
      );
      return response(200, { source: 'rds', orderId });
    }

    if (method === 'GET' && path.startsWith('/direct/item/')) {
      const id = path.split('/').pop();
      const { rows } = await pool.query(ORDER_DETAIL_QUERY, [id]);
      if (rows.length === 0) {
        return response(404, { error: 'not found' });
      }
      return response(200, { source: 'rds', items: rows });
    }

    return response(404, { error: 'route not found' });
  } catch (err) {
    return response(500, { error: err.message });
  }
};
