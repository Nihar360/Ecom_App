import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  User? _user;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = "All orders";

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    FirebaseAuth auth = FirebaseAuth.instance;
    _user = auth.currentUser;

    if (_user != null) {
      await _fetchOrders(_user!.uid);
    } else {
      print("User not authenticated");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchOrders(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference ordersCollectionRef = firestore.collection('orders');

    try {
      QuerySnapshot ordersQuerySnapshot = await ordersCollectionRef
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        _orders = ordersQuerySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          print("Document ID: ${doc.id}");
          print("Document Data: ${data}");
          return {
            'orderId': doc.id,
            'subtotal': (data['subtotal'] as num?)?.toDouble() ?? 0.0,
            'status': data['status']?.toString() ?? 'Unknown',
            'createdAt': data['createdAt'] as Timestamp?,
            'cancelledAt': data['cancelledAt'] as Timestamp?,
            'items': data['items'] as List<dynamic>? ?? [],
            'shippingAddress': data['shippingAddress']?.toString() ?? 'No address',
            'deliveryCharge': (data['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
            'userId': data['userId']?.toString() ?? 'N/A',
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching orders: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('orders').doc(orderId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      await _loadOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error cancelling order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Date not available';
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd.MM.yyyy at hh:mm a').format(dateTime);
  }

  List<Map<String, dynamic>> getFilteredOrders() {
    List<Map<String, dynamic>> filteredOrders;

    // Apply the filter based on the selected status
    if (_selectedFilter == "All orders") {
      filteredOrders = _orders;
    } else {
      filteredOrders = _orders
          .where((order) =>
      order['status'].toLowerCase() == _selectedFilter.toLowerCase())
          .toList();
    }

    // Sort the filtered orders, placing "Cancelled" orders at the end
    filteredOrders.sort((a, b) {
      if (a['status'] == 'Cancelled' && b['status'] != 'Cancelled') {
        return 1; // Cancelled orders go last
      } else if (a['status'] != 'Cancelled' && b['status'] == 'Cancelled') {
        return -1; // Non-cancelled orders go first
      } else {
        // Within the same group (cancelled or not), sort by createdAt (newest first)
        Timestamp? aTime = a['createdAt'];
        Timestamp? bTime = b['createdAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // Nulls last
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Newest first
      }
    });

    return filteredOrders;
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredOrders = getFilteredOrders();

    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Color(0xFF304FFE),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Orders",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "You have ${_orders.length} new order${_orders.length != 1 ? 's' : ''}",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _user == null
          ? Center(child: Text("Please log in to view orders"))
          : filteredOrders.isEmpty
          ? Center(child: Text("No orders found for this filter."))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFilterButton("All orders"),
                  _buildFilterButton("In progress"),
                  _buildFilterButton("Delivered"),
                  _buildFilterButton("Cancelled"),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return OrderCard(
                    order: order,
                    formatTimestamp: _formatTimestamp,
                    onCancel: _cancelOrder,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filterName) {
    bool isSelected = _selectedFilter == filterName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedFilter = filterName;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Color(0xFF304FFE) : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(filterName),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({
    Key? key,
    required this.order,
    required this.formatTimestamp,
    required this.onCancel,
  }) : super(key: key);

  final Map<String, dynamic> order;
  final String Function(Timestamp? timestamp) formatTimestamp;
  final Future<void> Function(String orderId) onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildProductItemWidgets(order['items']),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Subtotal:",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  "₹${order['subtotal'].toStringAsFixed(2)}",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Shipping:",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Flexible(
                  child: Text(
                    order['shippingAddress'] ?? 'No address',
                    style: TextStyle(color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Shipping Cost:",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  "₹${order['deliveryCharge'].toStringAsFixed(2)}",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Status:",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order['status'] == 'Delivered'
                        ? Colors.green.withOpacity(0.1)
                        : order['status'] == 'In progress'
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: order['status'] == 'Delivered'
                          ? Colors.green
                          : order['status'] == 'In progress'
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Created On:",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  formatTimestamp(order['createdAt']),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            if (order['status'] != 'Cancelled' && order['status'] != 'Delivered')
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ElevatedButton(
                  onPressed: () => onCancel(order['orderId']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel Order',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            if (order['status'] == 'Cancelled' && order['cancelledAt'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Cancelled On:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      formatTimestamp(order['cancelledAt']),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProductItemWidgets(List<dynamic> items) {
    return items.map((item) {
      final product = item as Map<String, dynamic>? ?? {};
      return Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['name']?.toString() ?? 'Unknown Product',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Weight: ${product['variant']?.toString() ?? 'N/A'}g"),
                Text("Quantity: ${product['quantity']?.toInt() ?? 0}"),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}