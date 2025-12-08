import mongoose, { Schema, Document } from 'mongoose';

export interface IStaff extends Document {
  name: string;
  email: string;
  phone: string;
  position: string;
  joinDate: Date;
  salary?: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const StaffSchema = new Schema<IStaff>(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    phone: { type: String, required: true },
    position: { type: String, required: true },
    joinDate: { type: Date, required: true },
    salary: { type: Number },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

export default mongoose.models.Staff || mongoose.model<IStaff>('Staff', StaffSchema);
