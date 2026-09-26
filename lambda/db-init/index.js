const { Pool } = require('pg');

const NUM_CUSTOMERS = 500;
const NUM_PRODUCTS = 200;
const NUM_ORDERS = 5000;
const MAX_ITEMS_PER_ORDER = 4;
const NUM_REVIEWS = 3000;

const CITIES = ['Guadalajara', 'CDMX', 'Monterrey', 'Puebla', 'Queretaro', 'Merida'];
const CATEGORIES = ['electronics', 'home', 'sports', 'books', 'toys', 'grocery'];
const STATUSES = ['pending', 'paid', 'shipped', 'delivered', 'cancelled'];

exports.handler = async () => {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    max: 1,
    ssl: { rejectUnauthorized: false },
  });

  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS customers (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        city TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        sku TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price NUMERIC(10, 2) NOT NULL
      );

      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        status TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS order_items (
        id SERIAL PRIMARY KEY,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        quantity INTEGER NOT NULL,
        unit_price NUMERIC(10, 2) NOT NULL
      );

      CREATE TABLE IF NOT EXISTS reviews (
        id SERIAL PRIMARY KEY,
        product_id INTEGER NOT NULL REFERENCES products(id),
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        rating INTEGER NOT NULL,
        comment TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
      CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
      CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
      CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON reviews(product_id);
    `);

    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM orders');
    if (rows[0].count > 0) {
      return { status: 'ok', seeded: false };
    }

    // Data is generated and inserted server-side (set-based SQL) instead of one
    // round trip per row, since ~21k sequential inserts over the network could
    // not finish inside the Lambda timeout.
    await pool.query(
      `INSERT INTO customers (name, email, city)
       SELECT 'customer-' || i,
              'customer-' || i || '@example.com',
              ($1::text[])[floor(random() * $2)::int + 1]
       FROM generate_series(1, $3) AS i`,
      [CITIES, CITIES.length, NUM_CUSTOMERS]
    );

    await pool.query(
      `INSERT INTO products (sku, name, category, price)
       SELECT 'SKU-' || i,
              'product-' || i,
              ($1::text[])[floor(random() * $2)::int + 1],
              round((random() * 495 + 5)::numeric, 2)
       FROM generate_series(1, $3) AS i`,
      [CATEGORIES, CATEGORIES.length, NUM_PRODUCTS]
    );

    await pool.query(
      `WITH new_orders AS (
         INSERT INTO orders (customer_id, status)
         SELECT floor(random() * $1)::int + 1,
                ($2::text[])[floor(random() * $3)::int + 1]
         FROM generate_series(1, $4) AS i
         RETURNING id
       ), order_item_counts AS (
         SELECT id, floor(random() * $5)::int + 1 AS item_count FROM new_orders
       )
       INSERT INTO order_items (order_id, product_id, quantity, unit_price)
       SELECT oic.id,
              floor(random() * $6)::int + 1,
              floor(random() * 5)::int + 1,
              round((random() * 495 + 5)::numeric, 2)
       FROM order_item_counts oic, generate_series(1, oic.item_count)`,
      [NUM_CUSTOMERS, STATUSES, STATUSES.length, NUM_ORDERS, MAX_ITEMS_PER_ORDER, NUM_PRODUCTS]
    );

    await pool.query(
      `INSERT INTO reviews (product_id, customer_id, rating, comment)
       SELECT floor(random() * $1)::int + 1,
              floor(random() * $2)::int + 1,
              floor(random() * 5)::int + 1,
              'review-' || i
       FROM generate_series(1, $3) AS i`,
      [NUM_PRODUCTS, NUM_CUSTOMERS, NUM_REVIEWS]
    );

    return { status: 'ok', seeded: true };
  } finally {
    await pool.end();
  }
};
