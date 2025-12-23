import mongoose from 'mongoose';

const ReturnSchema = new mongoose.Schema({
    productId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Product',
        required: true
    },
    productName: {
        type: String,
        required: true
    },
    returnType: {
        type: String,
        enum: ['customer', 'supplier'],
        required: true
    },
    quantity: {
        type: Number,
        required: true,
        min: 1
    },
    reason: {
        type: String,
        required: true
    },
    notes: {
        type: String,
        default: ''
    },
    unitPrice: {
        type: Number,
        required: true
    },
    totalValue: {
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
    cashier: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    cashierName: {
        type: String,
        required: true
    },
    status: {
        type: String,
        enum: ['pending', 'completed', 'cancelled'],
        default: 'completed'
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

// Add indexes for better query performance
ReturnSchema.index({ productId: 1, createdAt: -1 });
ReturnSchema.index({ returnType: 1, createdAt: -1 });
ReturnSchema.index({ createdAt: -1 });
ReturnSchema.index({ cashier: 1, createdAt: -1 });

export default mongoose.models.Return || mongoose.model('Return', ReturnSchema);