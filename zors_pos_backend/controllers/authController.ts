import bcrypt from 'bcryptjs'
import User from '../models/User'
import jwt from 'jsonwebtoken'
import { Request, Response } from 'express'

export async function registerUser(req: Request, res: Response) {

    try {
        const { username, email, password, role } = req.body

        // Check if user already exists
        const existingUser = await User.findOne({ username });
        if (existingUser) {
            return res.status(400).json({ message: 'Username already taken' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 12);

        // Create new user
        const user = new User({
            username,
            email,
            password: hashedPassword,
            role
        });
        await user.save();

        return res.status(201).json(user);
    } catch (error) {
        console.error('Error registering user:', error);
        return res.status(500).json({ message: 'Internal server error', error });
    }
    
}

export async function loginUser(req: Request, res: Response) {
    try {
        
        const { username, password } = req.body

        // validations
        if (!username || !password) {
            return res.status(400).json({ message: 'Please provide username and password' });
        }

        // Check if user exists
        const user = await User.findOne({ username });
        if (!user) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        // Check password
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        // generate jwt token
        const token = jwt.sign(
            { userId: user._id, username: user.username, role: user.role },
            'zorspos_jwt_secret',
            { expiresIn: '30d' }
        );

        const userRespose = {
            _id: user._id,
            username: user.username,
            email: user.email,
            role: user.role
        };

        return res.json({ token, user: userRespose });

    } catch (error) {
        console.error('Error logging in user:', error);
        return res.status(500).json({ message: 'Internal server error', error });        
    }
}

export async function changePassword(req: Request, res: Response) {
    try {
        
        const { oldPassword, newPassword } = req.body;

        const admin = await User.findById(req.user?.userId);
        if (!admin) {
            return res.status(404).json({ message: 'User not found' });
        }

        const isMatch = await bcrypt.compare(oldPassword, admin.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Old password is incorrect' });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 12);
        admin.password = hashedPassword;
        await admin.save();

        return res.json({ message: 'Password changed successfully' });

    } catch (error) {
        console.error('Error changing password:', error);
        return res.status(500).json({ message: 'Internal server error', error });
    }
}