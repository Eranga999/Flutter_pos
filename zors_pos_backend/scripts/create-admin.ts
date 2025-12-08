import '../src/setupEnv';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import User from '../src/models/User';

const createAdminUser = async () => {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
      throw new Error('MONGODB_URI environment variable is not defined');
    }

    await mongoose.connect(mongoUri);
    console.log('✓ Connected to MongoDB');

    // Check if admin already exists
    const existingAdmin = await User.findOne({ role: 'admin' });
    if (existingAdmin) {
      console.log('✓ Admin user already exists:', existingAdmin.email);
      process.exit(0);
    }

    // Create admin user
    const hashedPassword = await bcrypt.hash('admin123456', 10);
    const adminUser = new User({
      email: 'admin@zors.com',
      username: 'admin',
      password: hashedPassword,
      role: 'admin',
      isActive: true,
    });

    await adminUser.save();
    console.log('✓ Admin user created successfully');
    console.log('  Email: admin@zors.com');
    console.log('  Username: admin');
    console.log('  Password: admin123456');
    console.log('\n⚠️  Change this password after first login!');

    process.exit(0);
  } catch (error) {
    console.error('✗ Error creating admin user:', error);
    process.exit(1);
  }
};

createAdminUser();
