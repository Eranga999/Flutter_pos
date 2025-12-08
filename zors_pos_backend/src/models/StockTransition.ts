import mongoose, { Schema, Document } from 'mongoose';

export interface IStockTransition extends Document {
  productId: string;
  type: 'in' | 'out' | 'adjustment';
  quantity: number;
  previousStock: number;
  newStock: number;
  reason?: string;
  reference?: string;
  createdBy?: string;
  createdAt: Date;
}

const StockTransitionSchema = new Schema<IStockTransition>(
  {
    productId: { type: String, required: true },
    type: { type: String, enum: ['in', 'out', 'adjustment'], required: true },
    quantity: { type: Number, required: true },
    previousStock: { type: Number, required: true },
    newStock: { type: Number, required: true },
    reason: { type: String },
    reference: { type: String },
    createdBy: { type: String },
  },
  { timestamps: true }
);

export default mongoose.models.StockTransition || mongoose.model<IStockTransition>('StockTransition', StockTransitionSchema);
