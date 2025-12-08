import mongoose, { Document, Schema } from 'mongoose';

export interface IOrder extends Document {
  name: string;
  cart: any[];
  customer?: any;
  cashier: any;
  orderType: 'dine-in' | 'takeaway' | 'delivery';
  appliedCoupon?: any;
  kitchenNote?: string;
  createdAt: Date;
  status: 'active' | 'completed';
  isDefault?: boolean;
  paymentDetails: any;
  tableCharge: number;
  deliveryCharge?: number;
  discountPercentage: number;
  totalAmount: number;
}

const orderSchema = new Schema<IOrder>(
  {
    name: { type: String, required: true },
    cart: { type: [Object], required: true },
    customer: { type: Object, default: {} },
    cashier: { type: Object, required: true },
    orderType: { type: String, enum: ['dine-in', 'takeaway', 'delivery'], required: true },
    appliedCoupon: { type: Object },
    kitchenNote: { type: String },
    status: { type: String, enum: ['active', 'completed'], default: 'active' },
    isDefault: { type: Boolean, default: false },
    paymentDetails: { type: Object, required: true },
    tableCharge: { type: Number, default: 0 },
    deliveryCharge: { type: Number, default: 0 },
    discountPercentage: { type: Number, default: 0 },
    totalAmount: { type: Number, required: true },
  },
  { timestamps: true }
);

export default mongoose.models.Order || mongoose.model<IOrder>('Order', orderSchema);
