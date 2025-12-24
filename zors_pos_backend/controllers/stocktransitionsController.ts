import StockTransition from "../models/StockTransition";
import Product from "../models/Product";
import { Request, Response } from "express";

// Define interfaces for type safety
interface StockTransitionFilter {
    productId?: string;
    transactionType?: string;
    createdAt?: {
        $gte?: Date;
        $lte?: Date;
    };
}

interface StockTransitionRequestBody {
    productId: string;
    transactionType: 'sale' | 'purchase' | 'customer_return' | 'supplier_return' | 'adjustment';
    quantity: number;
    unitPrice?: number;
    reference?: string;
    party?: {
        name: string;
        type: string;
        id: string;
    };
    userId: string;
    userName: string;
    notes?: string;
}

export async function getAllStockTransitions(req: Request, res: Response) {
    try {
        const page = parseInt(req.query.page as string) || 1;
        const limit = parseInt(req.query.limit as string) || 50;
        const productId = req.query.productId as string;
        const transactionType = req.query.transactionType as string;
        const startDate = req.query.startDate as string;
        const endDate = req.query.endDate as string;

        // Build filter object
        const filter: StockTransitionFilter = {};

        if (productId) {
            filter.productId = productId;
        }

        if (transactionType && transactionType !== 'all') {
            filter.transactionType = transactionType;
        }

        if (startDate || endDate) {
            filter.createdAt = {};
            if (startDate) {
                filter.createdAt.$gte = new Date(startDate);
            }
            if (endDate) {
                filter.createdAt.$lte = new Date(endDate);
            }
        }

        const skip = (page - 1) * limit;

        const [transitions, total] = await Promise.all([
            StockTransition.find(filter)
                .populate('productId', 'name barcode category')
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit),
            StockTransition.countDocuments(filter)
        ]);

        return res.status(200).json({
            transitions,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });

    } catch (error) {
        console.error('Error fetching stock transitions:', error);
        return res.status(500).json(
            { error: 'Failed to fetch stock transitions' }
        );
    }
}

export async function createStockTransition(req: Request, res: Response) {
    try {
        const requestBody: StockTransitionRequestBody = req.body;
        const {
            productId,
            transactionType,
            quantity,
            unitPrice = 0,
            reference,
            party,
            userId,
            userName,
            notes = ''
        } = requestBody;

        // Validate required fields
        if (!productId || !transactionType || !quantity || !userId || !userName) {
            return res.status(400).json(
                { error: 'Missing required fields' }
            );
        }

        // Get current product stock
        const product = await Product.findById(productId);
        if (!product) {
            return res.status(404).json(
                { error: 'Product not found' }
            );
        }

        const previousStock = product.stock;
        let newStock = previousStock;

        // Calculate new stock based on transaction type
        switch (transactionType) {
            case 'sale':
            case 'supplier_return':
                newStock = previousStock - quantity;
                break;
            case 'purchase':
            case 'customer_return':
                newStock = previousStock + quantity;
                break;
            case 'adjustment':
                newStock = quantity; // Direct stock adjustment
                break;
            default:
                return res.status(400).json(
                    { error: 'Invalid transaction type' }
                );
        }

        // Validate stock doesn't go negative
        if (newStock < 0) {
            return res.status(400).json(
                { error: 'Insufficient stock for this transaction' }
            );
        }

        // Create stock transition record
        const stockTransition = new StockTransition({
            productId,
            productName: product.name,
            transactionType,
            quantity: Math.abs(quantity),
            previousStock,
            newStock,
            unitPrice,
            totalValue: Math.abs(quantity) * unitPrice,
            reference,
            party,
            user: userId,
            userName,
            notes
        });

        await stockTransition.save();

        // Update product stock
        await Product.findByIdAndUpdate(productId, { stock: newStock });

        return res.status(201).json(stockTransition);

    } catch (error) {
        console.error('Error creating stock transition:', error);
        return res.status(500).json(
            { error: 'Failed to create stock transition' }
        );
    }
}