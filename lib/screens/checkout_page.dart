import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'basket_screen.dart';
import 'order_success_popup.dart';
import 'home_screen.dart';

class CheckoutPage extends StatefulWidget {
  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  User? _user;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _basketItems = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _addresses = [];
  String? _selectedAddressId;
  String? _selectedPaymentMethod;
  bool _isCODSelected = false;
  bool _isOrderSummaryExpanded = false;
  bool _isLoading = true;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    FirebaseAuth auth = FirebaseAuth.instance;
    _user = auth.currentUser;

    if (_user != null) {
      await _fetchUserData(_user!.uid);
      await _fetchBasketItems(_user!.uid);
      await _fetchPaymentMethods();
    } else {
      print("User not authenticated");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchUserData(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference userDocRef = firestore.collection('users').doc(userId);

    try {
      DocumentSnapshot userDocSnapshot = await userDocRef.get();
      if (userDocSnapshot.exists) {
        setState(() {
          _userData = userDocSnapshot.data() as Map<String, dynamic>;
          var addressesData = _userData?['addresses'];
          if (addressesData is List && addressesData.isNotEmpty) {
            _addresses = addressesData.asMap().entries.map((entry) {
              var addr = entry.value;
              if (addr is Map<String, dynamic>) {
                return {
                  'id': addr['id'] ?? UniqueKey().toString(),
                  'address': addr['address'] ?? 'No address',
                };
              } else if (addr is String) {
                return {
                  'id': UniqueKey().toString(),
                  'address': addr,
                };
              }
              return {'id': UniqueKey().toString(), 'address': 'Invalid address'};
            }).toList();
            // Set the first address as selected by default
            _selectedAddressId = _addresses[0]['id'];
          } else {
            _addresses = [{'id': UniqueKey().toString(), 'address': 'No addresses found'}];
            _selectedAddressId = _addresses[0]['id'];
          }
        });
      } else {
        print("User document not found");
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _addresses = [{'id': UniqueKey().toString(), 'address': 'Error loading addresses'}];
        _selectedAddressId = _addresses[0]['id'];
      });
    }
  }

  Future<void> _fetchBasketItems(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference basketCollectionRef =
    firestore.collection('users').doc(userId).collection('basket');

    try {
      QuerySnapshot basketQuerySnapshot = await basketCollectionRef.get();
      setState(() {
        _basketItems = basketQuerySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'productId': data['productId'],
            'name': data['name'],
            'image': data['image'],
            'price': data['price']?.toDouble() ?? 0.0,
            'quantity': data['quantity'] ?? 1,
            'variant': data['variant'],
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching basket items: $e");
    }
  }

  Future<void> _fetchPaymentMethods() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference paymentCollectionRef =
    firestore.collection('payment_methods');

    try {
      QuerySnapshot paymentQuerySnapshot = await paymentCollectionRef.get();
      setState(() {
        _paymentMethods = paymentQuerySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print("Error fetching payment methods: $e");
    }
  }

  void _showAddressPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Shipping Address"),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _addresses.map((address) {
                String addressId = address['id'] ?? address.keys.first;
                return RadioListTile<String>(
                  title: Text(address['address'] ?? 'No address'),
                  value: addressId,
                  groupValue: _selectedAddressId,
                  onChanged: (value) {
                    setState(() {
                      _selectedAddressId = value;
                    });
                    Navigator.pop(context);
                  },
                  activeColor: Colors.orange.shade700,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  double _calculateSubtotal() {
    double itemTotal = _basketItems.fold<double>(
        0, (sum, item) => sum + (item['price'] * item['quantity']));
    return itemTotal + 100.0;
  }

  String _getSelectedAddress() {
    if (_isLoading || _userData == null) return 'Loading...';
    if (_addresses.isEmpty) return 'No address available';
    // Always return the address at index 0 if no specific address is selected
    if (_selectedAddressId == null && _addresses.isNotEmpty) {
      return _addresses[0]['address'] ?? 'No address selected';
    }
    final address = _addresses.firstWhere(
          (addr) => addr['id'] == _selectedAddressId,
      orElse: () => _addresses[0], // Default to first address
    );
    return address['address'] ?? 'No address selected';
  }

  Future<void> _placeOrder() async {
    if (_user == null) return;

    setState(() => _isLoading = true);

    FirebaseFirestore firestore = FirebaseFirestore.instance;

    double subtotal = _basketItems.fold<double>(
        0, (sum, item) => sum + (item['price'] * item['quantity']));
    double deliveryCharge = 100.0;
    double total = subtotal + deliveryCharge;

    // Get the first address from the addresses list
    String shippingAddress = _addresses.isNotEmpty
        ? _addresses[0]['address'] ?? 'No address selected'
        : 'No address available';

    Map<String, dynamic> orderData = {
      'userId': _user!.uid,
      'email': _userData?['email'] ?? '',
      'userName': _userData?['name'] ?? 'Unknown',
      'phone': _userData?['mobile'] ?? '',
      'shippingAddress': shippingAddress,
      'paymentMethod': _isCODSelected ? 'Cash on Delivery' : _selectedPaymentMethod,
      'paymentDetails': _isCODSelected
          ? {'type': 'COD'}
          : _paymentMethods
          .firstWhere((method) => method['id'] == _selectedPaymentMethod,
          orElse: () => {'name': 'Unknown'})
          .cast<String, dynamic>(),
      'items': _basketItems.map((item) => {
        'productId': item['productId'],
        'name': item['name'],
        'image': item['image'],
        'price': item['price'],
        'quantity': item['quantity'],
        'variant': item['variant'],
        'itemTotal': (item['price'] * item['quantity']).toDouble(),
      }).toList(),
      'subtotal': subtotal,
      'deliveryCharge': deliveryCharge,
      'total': total,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      'orderId': DateTime.now().millisecondsSinceEpoch.toString(),
      'notes': _notesController.text,
    };

    try {
      DocumentReference orderRef = await firestore.collection('orders').add(orderData);

      await firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('orders')
          .doc(orderRef.id)
          .set({
        'orderId': orderRef.id,
        'total': total,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'itemCount': _basketItems.length,
        'shippingAddress': shippingAddress,
      });

      await _clearBasket();

      setState(() => _isLoading = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return OrderSuccessPopup(
            onContinueShopping: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomeScreen()),
                    (Route<dynamic> route) => false,
              );
            },
          );
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error placing order: $e');
    }
  }

  Future<void> _clearBasket() async {
    if (_user == null) return;

    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference basketCollectionRef =
    firestore.collection('users').doc(_user!.uid).collection('basket');

    try {
      QuerySnapshot basketQuerySnapshot = await basketCollectionRef.get();
      for (QueryDocumentSnapshot doc in basketQuerySnapshot.docs) {
        await basketCollectionRef.doc(doc.id).delete();
      }
      setState(() {
        _basketItems.clear();
      });
      print("Basket cleared successfully!");
    } catch (e) {
      print("Error clearing basket: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.orange.shade700,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "Naik & Sons",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: Colors.orange.shade700),
                SizedBox(width: 8),
                Text(
                  "Rs. ${_calculateSubtotal().toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _user == null
          ? Center(child: Text("User not authenticated..."))
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isOrderSummaryExpanded = !_isOrderSummaryExpanded;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isOrderSummaryExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.orange.shade700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Show order summary",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Rs. ${_calculateSubtotal().toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isOrderSummaryExpanded) ...[
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 10),
                      ..._basketItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Item Name',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    "${item['variant'] ?? 'N/A'}g, Quantity: ${item['quantity'] ?? 1}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "Rs. ${(item['price'] * (item['quantity'] ?? 1)).toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Delivery Charge",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            "Rs. 100.00",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Subtotal",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "Rs. ${_calculateSubtotal().toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Contact",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _userData?['mobile'] ?? 'No mobile number',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _userData?['email'] ?? 'Loading...',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Ship to",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: _showAddressPopup,
                          child: Text(
                            "Change",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _getSelectedAddress(),
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Payment method",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Column(
                children: [
                  ..._paymentMethods.map((method) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPaymentMethod = method['id'];
                          _isCODSelected = false;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedPaymentMethod == method['id']
                                ? Colors.orange.shade700
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Radio(
                                  value: method['id'],
                                  groupValue: _selectedPaymentMethod,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPaymentMethod = value as String?;
                                      _isCODSelected = false;
                                    });
                                  },
                                  activeColor: Colors.orange.shade700,
                                ),
                                Text(
                                  method['name'] ?? 'Payment Method',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            if (method['price'] != null)
                              Text(
                                "Rs. ${method['price']?.toStringAsFixed(2) ?? '0.00'}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCODSelected = !_isCODSelected;
                        if (_isCODSelected) _selectedPaymentMethod = null;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isCODSelected
                              ? Colors.orange.shade700
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _isCODSelected,
                                onChanged: (value) {
                                  setState(() {
                                    _isCODSelected = value ?? false;
                                    if (_isCODSelected) _selectedPaymentMethod = null;
                                  });
                                },
                                activeColor: Colors.orange.shade700,
                              ),
                              Text(
                                "Cash on Delivery (COD)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                "Order Notes (Optional)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Add any special instructions here...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade700,
                      Colors.orange.shade500,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade200,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: (_selectedPaymentMethod == null && !_isCODSelected)
                      ? null
                      : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    "Place Order",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Back",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        "Refund policy",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        "Privacy Policy",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        "Terms of service",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}