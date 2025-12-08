# ZORS POS - Backend API

A standalone REST API for the ZORS Point of Sale system built with Node.js, Express, and MongoDB.

## Prerequisites

- Node.js (v16 or higher)
- MongoDB (Atlas or local)
- npm or yarn

## Installation

1. Clone the repository and navigate to the backend folder:
```bash
cd zors_pos_backend
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file from `.env.example`:
```bash
cp .env.example .env
```

4. Update the `.env` file with your configuration:
- MongoDB connection URI
- JWT secret key
- Cloudinary credentials (optional, for image uploads)

## Development

Start the development server with hot reload:
```bash
npm run dev
```

The API will be available at `http://localhost:5000`

## Build

Compile TypeScript to JavaScript:
```bash
npm run build
```

## Production

Start the production server:
```bash
npm run start
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login user
- `POST /api/auth/register` - Register new user
- `POST /api/auth/change-password` - Change password (requires auth)

### Products
- `GET /api/products` - Get all products with filters
- `GET /api/products/:id` - Get single product
- `POST /api/products` - Create product (requires auth)
- `PUT /api/products/:id` - Update product (requires auth)
- `DELETE /api/products/:id` - Delete product (requires auth)

### Categories
- `GET /api/categories` - Get all categories
- `POST /api/categories` - Create category (requires auth)
- `PUT /api/categories/:id` - Update category (requires auth)
- `DELETE /api/categories/:id` - Delete category (requires auth)

### Customers
- `GET /api/customers` - Get all customers
- `GET /api/customers/:id` - Get single customer
- `POST /api/customers` - Create customer (requires auth)
- `PUT /api/customers/:id` - Update customer (requires auth)
- `DELETE /api/customers/:id` - Delete customer (requires auth)

### Orders
- `GET /api/orders` - Get all orders (requires auth)
- `GET /api/orders/:id` - Get single order (requires auth)
- `POST /api/orders` - Create order (requires auth)
- `PUT /api/orders/:id` - Complete order (requires auth)

### Discounts
- `GET /api/discounts` - Get all discounts
- `POST /api/discounts` - Create discount (requires auth)
- `PUT /api/discounts/:id` - Update discount (requires auth)
- `DELETE /api/discounts/:id` - Delete discount (requires auth)

### Suppliers
- `GET /api/suppliers` - Get all suppliers
- `POST /api/suppliers` - Create supplier (requires auth)
- `PUT /api/suppliers/:id` - Update supplier (requires auth)
- `DELETE /api/suppliers/:id` - Delete supplier (requires auth)

### Staff
- `GET /api/staff` - Get all staff
- `POST /api/staff` - Create staff member (requires auth)
- `PUT /api/staff/:id` - Update staff (requires auth)
- `DELETE /api/staff/:id` - Delete staff (requires auth)

## Project Structure

```
src/
├── config/           # Configuration files
├── models/           # MongoDB schemas
├── middleware/       # Express middleware
├── routes/           # API route handlers
└── server.ts         # Main server file
```

## Technologies Used

- **Express.js** - Web framework
- **MongoDB** - Database
- **Mongoose** - ODM
- **JWT** - Authentication
- **Bcryptjs** - Password hashing
- **Cloudinary** - Image storage
- **TypeScript** - Type safety

## License

MIT
