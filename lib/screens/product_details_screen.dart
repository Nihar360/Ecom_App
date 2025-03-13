import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:naik/screens/basket_screen.dart';
import 'package:naik/screens/login_screen.dart'; // Import the BasketScreen

class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  final String category;

  ProductDetailsScreen({required this.productId, required this.category});

  @override
  _ProductDetailsScreenState createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _selectedQuantityIndex = 0;
  List<Map<String, dynamic>> _weightVariants = [];
  bool _isLoading = true;
  Map<String, dynamic> _productData = {};
  bool _isCategoryMatch = true;
  String _errorMessage = ''; // To store error messages for display

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    try {
      DocumentSnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      if (productSnapshot.exists) {
        _productData = productSnapshot.data() as Map<String, dynamic>;

        // Null check and type check for category
        String? productCategory = _productData['category'] as String?;

        if (productCategory == null) {
          _isCategoryMatch = false;
          _errorMessage = "Product category is missing in database.";
          return;
        }

        if (productCategory != widget.category) {
          _isCategoryMatch = false;
          _errorMessage = "Product does not belong to this category.";
          return;
        } else {
          _isCategoryMatch = true;
        }

        // Handle variants
        if (_productData.containsKey('variants') && _productData['variants'] is List) {
          List<dynamic> rawWeightVariants = _productData['variants'];

          _weightVariants = rawWeightVariants.map((item) {
            Map<String, dynamic> variant = Map<String, dynamic>.from(item);
            double offerPrice = double.tryParse(variant['offerPrice']?.toString() ?? '0') ?? 0.0;
            double price = double.tryParse(variant['price']?.toString() ?? '0') ?? 0.0;
            String weight = variant['weight']?.toString() ?? 'Not Available';
            String quantity = variant['quantity']?.toString() ?? '';

            return {
              'weight': weight,
              'price': price,
              'offerPrice': offerPrice,
              'quantity': quantity,
            };
          }).toList();
        } else {
          _weightVariants = [
            {'weight': 'Not Available', 'price': 0.0, 'offerPrice': 0.0, 'quantity': ''}
          ];
        }
      } else {
        _isCategoryMatch = false;
        _errorMessage = "Product not found.";
      }
    } catch (e) {
      _isCategoryMatch = false;
      _errorMessage = "Error loading product data: $e";
      print(_errorMessage); // Print to console for debugging
      _weightVariants = [
        {'weight': 'Error', 'price': 0.0, 'offerPrice': 0.0, 'quantity': ''}
      ];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login Required"),
            content: Text("You must be logged in to like this product."),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Login"),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      final likeRef = FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('likes')
          .doc(user.uid); // Use user.uid as the document ID

      final snapshot = await likeRef.get();

      if (snapshot.exists) {
        await likeRef.delete(); // Delete the document
      } else {
        await likeRef.set({}); // Create an empty document
      }
    } catch (e) {
      print('Error updating like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like. Please try again.')),
      );
    }
  }

  Stream<bool> _isLikedStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in - returning false stream');
      return Stream.value(false);
    }

    final likeRef = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .collection('likes')
        .doc(user.uid); // Use user.uid as the document ID

    return likeRef.snapshots().map((snapshot) => snapshot.exists);
  }

  Future<void> _addToBasket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login Required"),
            content: Text("You must be logged in to add items to your basket."),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Login"),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      // Check if the product already exists in the basket
      final selectedVariant = _weightVariants[_selectedQuantityIndex];
      final basketRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('basket');

      final existingItemSnapshot = await basketRef
          .where('productId', isEqualTo: widget.productId)
          .where('variant', isEqualTo: selectedVariant['weight'])
          .get();

      if (existingItemSnapshot.docs.isNotEmpty) {
        // If the product with the same variant exists, update the quantity
        final docId = existingItemSnapshot.docs.first.id;
        final currentQuantity = existingItemSnapshot.docs.first.data()['quantity'] ?? 1;
        await basketRef.doc(docId).update({
          'quantity': currentQuantity + 1,
        });
      } else {
        // If the product doesn't exist, add a new entry
        await basketRef.add({
          'productId': widget.productId,
          'name': _productData['name'],
          'image': (_productData['images'] as List?)?.isNotEmpty == true
              ? _productData['images'][0]
              : 'https://via.placeholder.com/400',
          'price': selectedVariant['offerPrice'] > 0
              ? selectedVariant['offerPrice']
              : selectedVariant['price'],
          'quantity': 1,
          'variant': selectedVariant['weight'],
        });
      }

      // Navigate to BasketScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BasketScreen()),
      );

      // Show a confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product added to basket!')),
      );
    } catch (e) {
      print('Error adding to basket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to basket. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : !_isCategoryMatch
          ? Center(child: Text(_errorMessage))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: (_productData['images'] as List?)?.length ?? 1,
                itemBuilder: (context, index) {
                  String imageUrl =
                  ((_productData['images'] as List?)?.isNotEmpty == true)
                      ? (_productData['images'] as List)[index]
                      : 'https://via.placeholder.com/400';
                  return Image.network(imageUrl, fit: BoxFit.cover);
                },
              ),
            ),
            SizedBox(height: 16),

            // Product Name and Like Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (_productData['name'] as String?) ?? 'Unknown Product',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StreamBuilder<bool>(
                    stream: _isLikedStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final bool isLiked = snapshot.data!;
                        return IconButton(
                          icon: Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 30,
                          ),
                          onPressed: _toggleLike,
                        );
                      } else if (snapshot.hasError) {
                        print("Error loading like status: ${snapshot.error}");
                        return Text('Error loading like status');
                      } else {
                        return CircularProgressIndicator();
                      }
                    }),
              ],
            ),
            SizedBox(height: 8),

            // Weight Variants
            Text('Weight',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_weightVariants.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        _weightVariants[index]['weight']
                            .toString()
                            .contains('g')
                            ? _weightVariants[index]['weight'].toString()
                            : _weightVariants[index]['weight'].toString() +
                            "g",
                      ),
                      selected: _selectedQuantityIndex == index,
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedQuantityIndex =
                          selected ? index : _selectedQuantityIndex;
                        });
                      },
                      selectedColor: Colors.purple[100],
                      backgroundColor: Colors.grey[300],
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: 16),

            // Description
            Text('Description',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
                (_productData['description'] as String?) ??
                    'No description available.',
                style: TextStyle(fontSize: 14)),
            SizedBox(height: 16),

            // Price Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_weightVariants.isNotEmpty &&
                        _weightVariants[_selectedQuantityIndex]
                        ['offerPrice'] >
                            0)
                      Text(
                        '\₹${(_weightVariants[_selectedQuantityIndex]['offerPrice']).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    if (_weightVariants.isNotEmpty &&
                        _weightVariants[_selectedQuantityIndex]['price'] >
                            0)
                      Text(
                        '\₹${(_weightVariants[_selectedQuantityIndex]['price']).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize:
                          (_weightVariants[_selectedQuantityIndex]
                          ['offerPrice'] >
                              0)
                              ? 14
                              : 20,
                          fontWeight:
                          (_weightVariants[_selectedQuantityIndex]
                          ['offerPrice'] >
                              0)
                              ? FontWeight.normal
                              : FontWeight.bold,
                          color: (_weightVariants[_selectedQuantityIndex]
                          ['offerPrice'] >
                              0)
                              ? Colors.red
                              : Colors.black,
                          decoration:
                          (_weightVariants[_selectedQuantityIndex]
                          ['offerPrice'] >
                              0)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24),

            // Add to Basket Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A148C),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                ),
                onPressed: _addToBasket, // Call the new method
                child: Text('Add to basket',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Center(child: Text("Login Page")),
    );
  }
}