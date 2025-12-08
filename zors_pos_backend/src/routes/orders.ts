import express, { Router, Request, Response } from 'express';
import Order from '../models/Order';
import Product from '../models/Product';
import { verifyToken } from '../middleware/auth';

const router: Router = express.Router();

// Get all orders
router.get('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const orders = await Order.find().sort({ createdAt: -1 });
    return res.status(200).json(orders);
  } catch (error: unknown) {
    console.error('Error fetching orders:', error);
    return res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

// Get single order
router.get('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    return res.status(200).json(order);
  } catch (error: unknown) {
    console.error('Error fetching order:', error);
    return res.status(500).json({ error: 'Failed to fetch order' });
  }
});

// Create order
router.post('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const { cart, orderType, totalAmount, paymentDetails } = req.body;

    if (!cart || !orderType || !totalAmount) {
      return res.status(400).json({ message: 'Required fields missing' });
    }

    // Update product stock
    for (const item of cart) {
      const product = await Product.findById(item.productId);
      if (product) {
        product.stock -= item.quantity;
        await product.save();
      }
    }

    const order = new Order({
      name: `Order ${Date.now()}`,
      cart,
      orderType,
      totalAmount,
      paymentDetails,
      cashier: req.user,
      status: 'active',
    });

    await order.save();

    return res.status(201).json({ message: 'Order created', order });
  } catch (error: unknown) {
    console.error('Error creating order:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create order';
    return res.status(500).json({ message: errorMessage });
  }
});

// Complete order
router.put('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { status: 'completed' },
      { new: true }
    );
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    return res.status(200).json({ message: 'Order completed', order });
  } catch (error: unknown) {
    console.error('Error updating order:', error);
    return res.status(500).json({ error: 'Failed to update order' });
  }
});

export default router;
