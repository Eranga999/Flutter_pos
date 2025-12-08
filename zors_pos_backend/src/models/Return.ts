import mongoose, { Schema, Document } from 'mongoose';

export interface IReturn extends Document {
  orderId: string;
  productId: string;
  quantity: number;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: Date;
  updatedAt: Date;
}

const ReturnSchema = new Schema<IReturn>(
  {
    orderId: { type: String, required: true },
    productId: { type: String, required: true },
    quantity: { type: Number, required: true },
    reason: { type: String, required: true },
    status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
  },
  { timestamps: true }
);

export default mongoose.models.Return || mongoose.model<IReturn>('Return', ReturnSchema);
