import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkout_page.dart';

class BasketScreen extends StatefulWidget {
  @override
  _BasketScreenState createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> {
  List<Map<String, dynamic>> _basketItems = [];
  bool _isLoading = true;
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBasketItems();
  }

  Future<void> _loadBasketItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final basketSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('basket')
          .get();

      List<Map<String, dynamic>> basketItems = [];
      for (var doc in basketSnapshot.docs) {
        final data = doc.data();
        // Fetch stock quantity from products collection
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(data['productId'])
            .get();
        final stockQuantity = productDoc.exists
            ? (productDoc['quantity'] as int? ?? 0)
            : 0;

        basketItems.add({
          'id': doc.id,
          'productId': data['productId'],
          'name': data['name'],
          'image': data['image'],
          'price': data['price']?.toDouble() ?? 0.0,
          'quantity': data['quantity'] ?? 1,
          'variant': data['variant'],
          'stockQuantity': stockQuantity, // Add stock quantity
        });
      }

      setState(() {
        _basketItems = basketItems;
        _totalPrice = _basketItems.fold(0.0, (sum, item) {
          return sum + (item['price'] * item['quantity']);
        });
      });
    } catch (e) {
      print('Error loading basket items: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(String itemId, int newQuantity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Find the item to check stock
    final item = _basketItems.firstWhere((i) => i['id'] == itemId);
    final stockQuantity = item['stockQuantity'] ?? 0;

    // If newQuantity exceeds stock, prevent update
    if (newQuantity > stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add more: Stock limit reached (${stockQuantity})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newQuantity < 1) {
      await _removeItem(itemId);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('basket')
          .doc(itemId)
          .update({'quantity': newQuantity});

      setState(() {
        final itemIndex = _basketItems.indexWhere((item) => item['id'] == itemId);
        _basketItems[itemIndex]['quantity'] = newQuantity;
        _totalPrice = _basketItems.fold(0.0, (sum, item) {
          return sum + (item['price'] * item['quantity']);
        });
      });
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  Future<void> _removeItem(String itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('basket')
          .doc(itemId)
          .delete();

      setState(() {
        _basketItems.removeWhere((item) => item['id'] == itemId);
        _totalPrice = _basketItems.fold(0.0, (sum, item) {
          return sum + (item['price'] * item['quantity']);
        });
      });
    } catch (e) {
      print('Error removing item: $e');
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
        title: Text('Basket'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                final batch = FirebaseFirestore.instance.batch();
                final basketRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('basket');
                final snapshot = await basketRef.get();
                for (var doc in snapshot.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();

                setState(() {
                  _basketItems.clear();
                  _totalPrice = 0.0;
                });
              } catch (e) {
                print('Error clearing basket: $e');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _basketItems.isEmpty
          ? Center(child: Text('Your basket is empty'))
          : Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Delivery for FREE until the end of the month',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _basketItems.length,
              itemBuilder: (context, index) {
                final item = _basketItems[index];
                final currentQuantity = item['quantity'] ?? 1;
                final stockQuantity = item['stockQuantity'] ?? 0;

                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          child: Image.network(
                            item['image'] ?? 'https://via.placeholder.com/80',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.network('https://via.placeholder.com/80'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? 'Unknown Product',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item['variant'] != null &&
                                  item['variant'].isNotEmpty)
                                Text(
                                  '${item['variant']}g',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              SizedBox(height: 8),
                              Text(
                                '₹${item['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Quantity: '),
                                  IconButton(
                                    icon: Icon(Icons.remove),
                                    onPressed: () => _updateQuantity(
                                        item['id'], currentQuantity - 1),
                                  ),
                                  Text('$currentQuantity'),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: currentQuantity < stockQuantity
                                        ? () => _updateQuantity(
                                        item['id'], currentQuantity + 1)
                                        : null, // Disable if at stock limit
                                  ),
                                ],
                              ),
                              if (currentQuantity >= stockQuantity)
                                Text(
                                  'Max stock reached ($stockQuantity)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A148C),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      textStyle: TextStyle(fontSize: 18),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CheckoutPage()),
                      );
                    },
                    child: Text(
                      'Checkout',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}