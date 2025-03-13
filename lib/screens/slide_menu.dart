import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:naik/screens/profile_page.dart';
import 'package:naik/screens/shopping_address_page.dart';
import 'package:naik/screens/orders_page.dart';
import 'package:naik/screens/login_screen.dart'; // Updated import

class SlideMenu extends StatefulWidget {
  @override
  _SlideMenuState createState() => _SlideMenuState();
}

class _SlideMenuState extends State<SlideMenu> {
  String _userName = 'Loading...';
  String _userAddress = 'Loading...';
  bool _isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('User is authenticated. UID: ${user.uid}');

        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          print('User document exists.');
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          print('User data: $data');

          if (data.containsKey('addresses')) {
            List<dynamic>? addressesList = data['addresses'] as List<dynamic>?;

            if (addressesList != null && addressesList.isNotEmpty) {
              if (addressesList[0] is String) {
                setState(() {
                  _userName = data['name'] ?? 'Unknown User';
                  _userAddress = addressesList[0];
                  _isLoading = false;
                });
              } else {
                print("Error: First address in 'addresses' is not a String.");
                setState(() {
                  _userName = data['name'] ?? 'Unknown User';
                  _userAddress = 'Invalid address format';
                  _isLoading = false;
                });
              }
            } else {
              print("Info: 'addresses' list is null or empty.");
              setState(() {
                _userName = data['name'] ?? 'Unknown User';
                _userAddress = 'No address provided';
                _isLoading = false;
              });
            }
          } else {
            print("Info: 'addresses' field not found.");
            setState(() {
              _userName = data['name'] ?? 'Unknown User';
              _userAddress = 'No address provided';
              _isLoading = false;
            });
          }
        } else {
          print('User document does not exist.');
          setState(() {
            _userName = 'Unknown User';
            _userAddress = 'No address provided';
            _isLoading = false;
          });
        }
      } else {
        print('User is not authenticated.');
        setState(() {
          _userName = 'Not logged in';
          _userAddress = 'Not logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _userName = 'Error';
        _userAddress = 'Error';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      Navigator.pop(context); // Close the drawer
      // Replace current route with LoginScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()), // Updated to LoginScreen
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(),
          _buildDrawerItem(
            text: 'My profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
          ),
          _buildDrawerItem(
            text: 'Shopping address',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ShoppingAddressPage()),
              );
            },
          ),
          _buildDrawerItem(
            text: 'Order history',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OrdersPage()),
              );
            },
          ),
          _buildDrawerItem(
            text: 'Notifications',
            onTap: () {
              Navigator.pop(context);
              // Navigate to Notifications screen or perform action
            },
          ),
          Divider(),
          _buildDrawerItem(
            text: 'About',
            onTap: () {
              Navigator.pop(context);
              // Navigate to About screen or perform action
            },
          ),
          _buildDrawerItem(
            text: 'Logout',
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: EdgeInsets.all(16.0),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _userName,
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  _userAddress,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required String text,
    required GestureTapCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}