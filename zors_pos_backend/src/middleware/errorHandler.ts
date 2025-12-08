import { Request, Response, NextFunction } from 'express';

export const errorHandler = (err: any, req: Request, res: Response, next: NextFunction) => {
  console.error('Error:', err);

  if (err.name === 'ValidationError') {
    return res.status(400).json({ message: 'Validation error', details: err.message });
  }

  if (err.name === 'MongoError' && (err as any).code === 11000) {
    return res.status(400).json({ message: 'Duplicate field value entered' });
  }

  return res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
  });
};
