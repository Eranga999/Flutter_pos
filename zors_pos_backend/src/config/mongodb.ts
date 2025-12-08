import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  throw new Error('MONGODB_URI environment variable is not defined');
}

export const connectDB = async () => {
  try {
    await mongoose.connect(MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
    } as any);
    console.log('✓ MongoDB connected successfully');
    return mongoose;
  } catch (error) {
    console.error('✗ MongoDB connection error:', error);
    throw error;
  }
};
