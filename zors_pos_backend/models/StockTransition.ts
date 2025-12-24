import mongoose from 'mongoose';

const StockTransitionSchema = new mongoose.Schema({
    productId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Product',
        required: true
    },
    productName: {
        type: String,
        required: true
    },
    transactionType: {
        type: String,
        enum: ['sale', 'purchase', 'customer_return', 'supplier_return', 'adjustment', 'delete'],
        required: true
    },
    quantity: {
        type: Number,
        required: true
    },
    previousStock: {
        type: Number,
        required: true
    },
    newStock: {
        type: Number,
        required: true
    },
    unitPrice: {
        type: Number,
        default: 0
    },
    totalValue: {
        type: Number,
        default: 0
    },
    reference: {
        type: String, // Order ID, Return ID, etc.
        default: null
    },
    party: {
        name: String,
        type: {
            type: String,
            enum: ['customer', 'supplier', 'system']
        },
        id: String
    },
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: false
    },
    userName: {
        type: String,
        required: true
    },
    notes: {
        type: String,
        default: ''
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

// Add indexes for better query performance
StockTransitionSchema.index({ productId: 1, createdAt: -1 });
StockTransitionSchema.index({ transactionType: 1, createdAt: -1 });
StockTransitionSchema.index({ createdAt: -1 });

export default mongoose.models.StockTransition || mongoose.model('StockTransition', StockTransitionSchema);