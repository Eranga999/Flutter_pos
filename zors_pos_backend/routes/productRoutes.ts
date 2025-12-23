import { Router } from 'express';
import { getAllProducts, getProductById, createProduct, updateProduct, deleteProduct, serveProductImage } from '../controllers/productsController';
import { upload } from '../utils/multer';

const router = Router();

// Public routes
router.get('/products', getAllProducts);
router.get('/products/:id', getProductById);
router.post('/products', upload.single('image'), createProduct);
router.put('/products/:id', upload.single('image'), updateProduct);
router.delete('/products/:id', deleteProduct);

// Image serving endpoint
router.get('/products/images/:productId/:filename', serveProductImage);

export default router;