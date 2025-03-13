import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_details_screen.dart'; // Import your product details screen

class LikedProductsScreen extends StatefulWidget {
  @override
  _LikedProductsScreenState createState() => _LikedProductsScreenState();
}

class _LikedProductsScreenState extends State<LikedProductsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Liked Products')),
        body: Center(
            child: Text('You must be logged in to view your liked products.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Liked Products',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>( // Fetch DocumentSnapshot directly
        future: _getLikedProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("Error loading liked products: ${snapshot.error}");
            return Center(child: Text('Error loading liked products.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('You have not liked any products yet.'));
          }

          return _buildLikedProducts(snapshot.data!);
        },
      ),
    );
  }

  /// Fetches the list of product IDs that the user has liked.
  Future<List<DocumentSnapshot>> _getLikedProducts() async {
    List<DocumentSnapshot> likedProducts = [];

    try {
      // Get a reference to the 'likes' subcollection for each product.
      QuerySnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();

      for (var productDoc in productSnapshot.docs) {

        DocumentSnapshot likeDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productDoc.id)
            .collection('likes')
            .doc(user!.uid)
            .get();

        if(likeDoc.exists){
          likedProducts.add(productDoc); // Add DocumentSnapshot to list instead of product id
        }
      }

    } catch (e) {
      print("Error fetching liked products: $e");
    }

    print("Liked Product IDs: ${likedProducts.map((doc) => doc.id).toList()}"); // Debug: Print the IDs
    return likedProducts;
  }

  /// Builds the UI for displaying liked products
  Widget _buildLikedProducts(List<DocumentSnapshot> products) { // Use DocumentSnapshot as parameter type
    return GridView.builder(
      padding: EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65, // Adjusted aspect ratio for taller cards
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        var product = products[index];
        return _buildProductCard(context, product); // Pass DocumentSnapshot to build card
      },
    );
  }

  //------------------------Copy from HomeScreen.dart starts here----------------------------

  Widget _buildProductCard(BuildContext context, DocumentSnapshot product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              productId: product.id,
              category: product['category'],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // More rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15), // Softer shadow
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent, // No background color from Material
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(
                      productId: product.id,
                      category: product['category'],
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          child: Image.network(
                            product['images'][0] ?? 'https://via.placeholder.com/300',
                            fit: BoxFit.contain, // Use BoxFit.contain to show the full image
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset('assets/all.png', width: 50, height: 50),
                          ),
                        ),
                        // Gradient Overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.05),
                                  Colors.black.withOpacity(0.15),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.black87), // Darker text
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '\₹${product['offerPrice'] ?? 0}',
                              style: TextStyle(
                                  color: Colors.deepPurpleAccent, // Modern accent color
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '\₹${product['price'] ?? 0}',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (product['price'] != null && product['offerPrice'] != null)
                          _buildDiscountPercentage(product['price'], product['offerPrice']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountPercentage(dynamic originalPrice, dynamic offerPrice) {
    double original = (originalPrice is int) ? originalPrice.toDouble() : originalPrice;
    double offer = (offerPrice is int) ? offerPrice.toDouble() : offerPrice;

    double discountPercentage = ((original - offer) / original) * 100;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Adjusted padding
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(6), // Slightly more rounded
      ),
      child: Text(
        '${discountPercentage.toStringAsFixed(0)}% off',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Unlikes a product by removing the user's like document
  Future<void> _unlikeProduct(String productId) async {
    try {

      DocumentReference likeDoc = FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('likes')
          .doc(user!.uid);

      await likeDoc.delete();

    } catch (e) {
      print('Error unliking product: $e');
    }
  }
}