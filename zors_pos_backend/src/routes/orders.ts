import express, { Router, Request, Response } from 'express';
import Order from '../models/Order';
import Product from '../models/Product';
import { Types } from 'mongoose';
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
    const { cart, orderType, totalAmount, paymentDetails, discountPercentage } = req.body;

    if (!cart || !orderType || !totalAmount) {
      return res.status(400).json({ success: false, message: 'Required fields missing' });
    }

    // Update product stock (atomic, validated) -- supports ObjectId or string ids
    for (const item of cart) {
      const productId = Types.ObjectId.isValid(item.productId)
        ? new Types.ObjectId(item.productId)
        : item.productId;

      const updateResult = await Product.updateOne(
        { _id: productId, stock: { $gte: item.quantity } },
        { $inc: { stock: -item.quantity } }
      );

      if (updateResult.matchedCount === 0) {
        console.error('Stock update failed: product not found', { productId });
        return res.status(404).json({
          success: false,
          message: `Product not found: ${item.productId}`,
        });
      }

      if (updateResult.modifiedCount === 0) {
        console.error('Stock update failed: insufficient stock', {
          productId,
          requested: item.quantity,
        });
        return res.status(400).json({
          success: false,
          message: `Insufficient stock for product ${item.productName || item.productId}`,
        });
      }

      console.log(
        `Stock decremented for product ${item.productName || item.productId} by ${item.quantity}`
      );
    }

    // Extract kitchen notes from payment details
    const kitchenNote = paymentDetails?.notes || '';

    const order = new Order({
      name: `Order ${Date.now()}`,
      cart,
      orderType,
      totalAmount,
      paymentDetails,
      cashier: req.user,
      status: 'completed',
      kitchenNote,
      discountPercentage: discountPercentage || 0,
    });

    await order.save();
    console.log('Order created successfully:', order._id);

    return res.status(201).json({ success: true, message: 'Order created', data: { order } });
  } catch (error: unknown) {
    console.error('Error creating order:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create order';
    return res.status(500).json({ success: false, message: errorMessage });
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
