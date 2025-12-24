import jwt from 'jsonwebtoken'
import { Request, Response, NextFunction } from 'express'

interface JwtPayload {
  userId: string
  username: string
  role: string
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload
    }
  }
}

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  try {
    const token = req.headers.authorization?.split(' ')[1] // Bearer TOKEN

    if (!token) {
      return res.status(401).json({ message: 'No token provided' })
    }

    const decoded = jwt.verify(token, 'zorspos_jwt_secret') as JwtPayload
    return req.user = decoded
    next()
  } catch (error) {
    console.error('Auth middleware error:', error)
    return res.status(401).json({ message: 'Invalid or expired token' })
  }
}