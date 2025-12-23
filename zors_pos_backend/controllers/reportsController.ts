import { Request, Response } from 'express';
import Product from '../models/Product';
import Order from '../models/Order';
import StockTransition from '../models/StockTransition';
import Return from '../models/Return';
import Customer from '../models/Customer';
import User from '../models/User';

// Define interface for date filter
interface DateFilter {
    createdAt?: {
        $gte?: Date;
        $lte?: Date;
    };
}

export async function getReports(request: Request, response: Response) {
    try {

        const period = (request.query.period as string) || '30'; // days
        const startDate = request.query.startDate as string;
        const endDate = request.query.endDate as string;

        // Calculate date range
        let dateFilter: DateFilter = {};
        if (startDate && endDate) {
            dateFilter = {
                createdAt: {
                    $gte: new Date(startDate),
                    $lte: new Date(endDate)
                }
            };
        } else {
            const daysAgo = new Date();
            daysAgo.setDate(daysAgo.getDate() - parseInt(period));
            dateFilter = {
                createdAt: { $gte: daysAgo }
            };
        }

        // Parallel data fetching for better performance
        const [
            // Basic counts
            totalProducts,
            totalCustomers,
            totalUsers,
            lowStockProducts,
            outOfStockProducts,

            // Sales data
            orders,
            totalRevenue,
            todayRevenue,

            // Stock movements
            stockTransitions,
            returns,

            // Top performing data
            topProducts,
            recentOrders,
            recentReturns
        ] = await Promise.all([
            // Basic counts
            Product.countDocuments(),
            Customer.countDocuments(),
            User.countDocuments(),
            Product.countDocuments({ stock: { $lt: 10, $gt: 0 } }),
            Product.countDocuments({ stock: 0 }),

            // Sales data
            Order.find(dateFilter).populate('cart.product'),
            Order.aggregate([
                { $match: dateFilter },
                { $group: { _id: null, total: { $sum: '$totalAmount' } } }
            ]),
            Order.aggregate([
                {
                    $match: {
                        createdAt: {
                            $gte: new Date(new Date().setHours(0, 0, 0, 0))
                        }
                    }
                },
                { $group: { _id: null, total: { $sum: '$totalAmount' } } }
            ]),

            // Stock movements
            StockTransition.find(dateFilter).populate('productId', 'name'),
            Return.find(dateFilter).populate('productId', 'name'),

            // Top products by sales volume
            Order.aggregate([
                { $match: dateFilter },
                { $unwind: '$cart' },
                {
                    $group: {
                        _id: '$cart.product._id',
                        productName: { $first: '$cart.product.name' },
                        totalQuantity: { $sum: '$cart.quantity' },
                        totalRevenue: { $sum: { $multiply: ['$cart.quantity', '$cart.product.sellingPrice'] } }
                    }
                },
                { $sort: { totalQuantity: -1 } },
                { $limit: 10 }
            ]),

            // Recent orders
            Order.find().sort({ createdAt: -1 }).limit(10).populate('cashier', 'username'),

            // Recent returns
            Return.find().sort({ createdAt: -1 }).limit(10).populate('productId', 'name').populate('cashier', 'username')
        ]);

        // Process sales by day for charts
        const salesByDay = await Order.aggregate([
            { $match: dateFilter },
            {
                $group: {
                    _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
                    revenue: { $sum: '$totalAmount' },
                    orders: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ]);

        // Stock transition summary
        const stockSummary = await StockTransition.aggregate([
            { $match: dateFilter },
            {
                $group: {
                    _id: '$transactionType',
                    count: { $sum: 1 },
                    totalValue: { $sum: '$totalValue' }
                }
            }
        ]);

        // Category performance
        const categoryPerformance = await Product.aggregate([
            {
                $group: {
                    _id: '$category',
                    totalProducts: { $sum: 1 },
                    totalStock: { $sum: '$stock' },
                    averagePrice: { $avg: '$sellingPrice' }
                }
            },
            { $sort: { totalProducts: -1 } }
        ]);

        // Payment method breakdown
        const paymentMethods = await Order.aggregate([
            { $match: dateFilter },
            {
                $group: {
                    _id: '$paymentDetails.method',
                    count: { $sum: 1 },
                    totalAmount: { $sum: '$totalAmount' }
                }
            }
        ]);

        // Calculate net profit (total revenue - total cost)
        const netProfitData = await Order.aggregate([
            { $match: dateFilter },
            { $unwind: '$cart' },
            {
                $group: {
                    _id: null,
                    totalRevenue: {
                        $sum: {
                            $multiply: ['$cart.quantity', '$cart.product.sellingPrice']
                        }
                    },
                    totalCost: {
                        $sum: {
                            $multiply: ['$cart.quantity', '$cart.product.costPrice']
                        }
                    }
                }
            },
            {
                $project: {
                    totalRevenue: 1,
                    totalCost: 1,
                    netProfit: { $subtract: ['$totalRevenue', '$totalCost'] },
                    profitMargin: {
                        $cond: {
                            if: { $gt: ['$totalRevenue', 0] },
                            then: {
                                $multiply: [
                                    { $divide: [{ $subtract: ['$totalRevenue', '$totalCost'] }, '$totalRevenue'] },
                                    100
                                ]
                            },
                            else: 0
                        }
                    }
                }
            }
        ]);

        const profitData = netProfitData[0] || {
            totalRevenue: 0,
            totalCost: 0,
            netProfit: 0,
            profitMargin: 0
        };

        const reportData = {
            // Overview metrics
            overview: {
                totalProducts,
                totalCustomers,
                totalUsers,
                lowStockProducts,
                outOfStockProducts,
                totalRevenue: totalRevenue[0]?.total || 0,
                todayRevenue: todayRevenue[0]?.total || 0,
                totalOrders: orders.length,
                totalReturns: returns.length,
                netProfit: profitData.netProfit,
                totalCost: profitData.totalCost,
                profitMargin: profitData.profitMargin
            },

            // Charts data
            salesByDay: salesByDay.map(day => ({
                date: day._id,
                revenue: day.revenue,
                orders: day.orders
            })),

            stockSummary: stockSummary.map(item => ({
                type: item._id,
                count: item.count,
                value: item.totalValue
            })),

            categoryPerformance: categoryPerformance.map(cat => ({
                category: cat._id || 'Uncategorized',
                products: cat.totalProducts,
                stock: cat.totalStock,
                averagePrice: cat.averagePrice
            })),

            paymentMethods: paymentMethods.map(pm => ({
                method: pm._id || 'cash',
                count: pm.count,
                amount: pm.totalAmount
            })),

            // Top performers
            topProducts: topProducts.map(product => ({
                id: product._id,
                name: product.productName,
                quantity: product.totalQuantity,
                revenue: product.totalRevenue
            })),

            // Recent activities
            recentOrders: recentOrders.map(order => ({
                id: order._id,
                totalAmount: order.totalAmount,
                orderType: order.orderType,
                cashier: order.cashier?.username || 'Unknown',
                createdAt: order.createdAt,
                itemCount: order.cart?.length || 0
            })),

            recentReturns: recentReturns.map(returnItem => ({
                id: returnItem._id,
                productName: returnItem.productName,
                quantity: returnItem.quantity,
                returnType: returnItem.returnType,
                reason: returnItem.reason,
                cashier: returnItem.cashierName,
                createdAt: returnItem.createdAt
            })),

            // Additional insights
            insights: {
                averageOrderValue: orders.length > 0 ? (totalRevenue[0]?.total || 0) / orders.length : 0,
                returnRate: orders.length > 0 ? (returns.length / orders.length) * 100 : 0,
                stockTurnover: stockTransitions.filter(t => t.transactionType === 'sale').length
            }
        };

        return response.status(200).json(reportData);

    } catch (error) {
        console.error('Error generating reports:', error);
        return response.status(500).json(
            { error: 'Failed to generate reports' }
        );
    }
}