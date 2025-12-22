import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'pos_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header - removed (status bar shown by phone)
              const SizedBox(height: 16),

              // Logo Section
              _buildLogoSection(),

              const SizedBox(height: 60),

              // Welcome Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Welcome ${user?.name ?? 'Admin'}!',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 37,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Menu Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    // First Row: POS and Inventory
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMenuCard(
                          context,
                          label: 'POS',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const PosScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          label: 'Inventory',
                          onTap: () {
                            // Navigate to Inventory screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Inventory feature coming soon'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Second Row: Reports and Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMenuCard(
                          context,
                          label: 'Reports',
                          onTap: () {
                            // Navigate to Reports screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reports feature coming soon'),
                              ),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          label: 'Category',
                          onTap: () {
                            // Navigate to Category screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Category feature coming soon'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      authProvider.logout();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF324137),
                        width: 2.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF324137),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          children: [
            // Logo Image
            Container(
              width: 72,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                    ),
                    child: const Icon(
                      Icons.storefront,
                      size: 40,
                      color: Color(0xFF324137),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Brand Name
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Zors',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324137),
                      fontFamily: 'Inter',
                    ),
                  ),
                  TextSpan(
                    text: 'Code',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC8E260),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 172,
        height: 189,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFF324137), width: 3),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
