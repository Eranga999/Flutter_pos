import mongoose, { Document, Schema } from "mongoose";

export interface Discount extends Document {
  name: string;
  percentage: number;
  isGlobal: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const DiscountSchema = new Schema<Discount>({
    name: { type: String, required: true },
    percentage: { type: Number, required: true, min: 0, max: 100 },
    isGlobal: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
}, { timestamps: true })

export default mongoose.models.Discount || mongoose.model<Discount>('Discount', DiscountSchema);