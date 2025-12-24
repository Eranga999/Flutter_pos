import OrderModel from "../models/Order";
import Product from "../models/Product";
import StockTransition from "../models/StockTransition";
import { Request, Response } from "express";

// Define interfaces for type safety
interface ProductData {
    _id: string;
    name: string;
    sellingPrice: number;
    stock: number;
}

interface CartItem {
    product: ProductData;
    quantity: number;
}

interface Customer {
    _id?: string;
    name: string;
}

interface Cashier {
    _id: string;
    username: string;
}

interface OrderData {
    cart: CartItem[];
    customer?: Customer;
    cashier: Cashier;
    orderType: string;
    kitchenNote?: string;
}

interface StockTransitionData {
    productId: string;
    productName: string;
    transactionType: 'sale';
    quantity: number;
    previousStock: number;
    newStock: number;
    unitPrice: number;
    totalValue: number;
    reference: string;
    party?: {
        name: string;
        type: 'customer';
        id: string;
    };
    user?: string;
    userName: string;
    notes: string;
}

export async function getAllOrders(_: Request, res: Response) {
    try {

        const orders = await OrderModel.find();

        return res.json(orders);
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
        return res.status(500).json({ error: errorMessage });
    }
}

export async function createOrder(req: Request, res: Response) {
    try {

        const orderData: OrderData = req.body;

        // Validate required fields
        if (!orderData.cart || !Array.isArray(orderData.cart) || orderData.cart.length === 0) {
            return res.status(400).json({ error: 'Cart is required and must contain items' });
        }

        // Fetch current stock for all products in cart BEFORE creating order
        const productIds = orderData.cart.map(item => item.product._id);
        const currentProducts = await Product.find({ _id: { $in: productIds } });
        
        // Create a map of product ID to current stock
        const stockMap = new Map<string, number>();
        currentProducts.forEach(product => {
            stockMap.set(product._id.toString(), product.stock);
        });

        // Create the order
        const order = new OrderModel(orderData);
        const savedOrder = await order.save();

        // Create stock transitions for each cart item using the fetched current stock
        try {
            const stockTransitions: StockTransitionData[] = orderData.cart.map((item: CartItem) => {
                const currentStock = stockMap.get(item.product._id.toString()) ?? item.product.stock;
                const newStock = currentStock - item.quantity;

                const transitionData: StockTransitionData = {
                    productId: item.product._id,
                    productName: item.product.name,
                    transactionType: 'sale' as const,
                    quantity: item.quantity,
                    previousStock: currentStock,
                    newStock: newStock,
                    unitPrice: item.product.sellingPrice,
                    totalValue: item.quantity * item.product.sellingPrice,
                    reference: savedOrder._id.toString(),
                    userName: orderData.cashier.username,
                    notes: `Order ${orderData.orderType}${orderData.kitchenNote ? ' - ' + orderData.kitchenNote : ''}`
                };

                // Add party info if customer exists
                if (orderData.customer?.name) {
                    transitionData.party = {
                        name: orderData.customer.name,
                        type: 'customer' as const,
                        id: orderData.customer._id || 'walk-in'
                    };
                }

                // Only add user if it's a valid ObjectId
                if (orderData.cashier._id && /^[a-fA-F0-9]{24}$/.test(orderData.cashier._id)) {
                    transitionData.user = orderData.cashier._id;
                }

                return transitionData;
            });

            await StockTransition.insertMany(stockTransitions);
        } catch (transitionError) {
            console.error('Error creating stock transitions:', transitionError);
            // Don't fail the order if stock transition creation fails
        }

        return res.status(201).json(savedOrder);

    } catch (error: unknown) {
        console.error('Error creating order:', error);
        return res.status(500).json({ error: 'Failed to create order' });
    }
}

export async function getOrderById(req: Request, res: Response) {
    try {
        
        const id = req.params.id;
        const order = await OrderModel.findById(id);
        if (!order) {
            return res.status(404).json({ error: 'Order not found' });
        }

        return res.status(200).json(order);
    } catch (error) {
        console.error('Error fetching order:', error);
        return res.status(500).json({ error: 'Failed to fetch order' });
    }
}

export async function updateStock(req: Request, res: Response) {
    try {
        
        const { cartItems }: { cartItems: CartItem[] } = await req.body;

        if (!cartItems || !Array.isArray(cartItems)) {
            return res.status(400).json({ error: 'Invalid cart items provided' });
        }

        // Process each cart item to update stock
        const stockUpdates: { productId: string; productName: string; previousStock: number; soldQuantity: number; newStock: number }[] = [];
        const errors: string[] = [];

        for (const item of cartItems) {
            try {
                const product = await Product.findById(item.product._id);

                if (!product) {
                    errors.push(`Product with ID ${item.product._id} not found`);
                    continue;
                }

                // Check if there's enough stock
                if (product.stock < item.quantity) {
                    errors.push(`Insufficient stock for ${product.name}. Available: ${product.stock}, Required: ${item.quantity}`);
                    continue;
                }

                // Calculate new stock
                const newStock = product.stock - item.quantity;

                // Update the product stock
                const updatedProduct = await Product.findByIdAndUpdate(
                    item.product._id,
                    { stock: newStock },
                    { new: true, runValidators: true }
                );

                if (!updatedProduct) {
                    errors.push(`Failed to update stock for product ${product.name}`);
                    continue;
                }

                stockUpdates.push({
                    productId: item.product._id,
                    productName: product.name,
                    previousStock: product.stock,
                    soldQuantity: item.quantity,
                    newStock: newStock
                });

            } catch (error) {
                console.error(`Error updating stock for product ${item.product._id}:`, error);
                errors.push(`Failed to update stock for product ID ${item.product._id}`);
            }
        }

        // If there were any errors, return them
        if (errors.length > 0) {
            return res.status(207).json({
                error: 'Some stock updates failed',
                details: errors,
                successfulUpdates: stockUpdates
            }); // 207 Multi-Status
        }

        return res.status(200).json({
            message: 'Stock updated successfully',
            updates: stockUpdates
        });

    } catch (error) {
        console.error('Error updating product stock:', error);
        return res.status(500).json({ error: 'Failed to update product stock' });
    }
}