import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingAddressPage extends StatefulWidget {
  @override
  _ShoppingAddressPageState createState() => _ShoppingAddressPageState();
}

class _ShoppingAddressPageState extends State<ShoppingAddressPage> {
  final List<TextEditingController> _addressControllers = [];
  bool _isLoading = true;
  int _currentAddressIndex = 0; // Tracks the current shipping address
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();
        setState(() {
          _addressControllers.clear();
          if (userDoc.exists && userDoc['addresses'] != null) {
            List<dynamic> storedAddresses = userDoc['addresses'];
            if (storedAddresses.isNotEmpty) {
              for (var address in storedAddresses) {
                if (address is String) {
                  _addressControllers.add(TextEditingController(text: address));
                }
              }
            }
          }
          if (_addressControllers.isEmpty) {
            _addressControllers.add(TextEditingController(
                text: '43 Oxford Road, M13 4GR, Manchester, UK'));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching addresses: $e');
      setState(() {
        _addressControllers.clear();
        _addressControllers.add(TextEditingController(text: 'Error fetching addresses'));
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAddresses() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        List<String> addressesToSave = _addressControllers
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();

        if (addressesToSave.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please add at least one address')),
          );
          return;
        }

        await _firestore.collection('users').doc(user.uid).set({
          'addresses': addressesToSave,
        }, SetOptions(merge: true));

        // Return the current selected address to ProfilePage
        Navigator.pop(context, addressesToSave[_currentAddressIndex]);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Addresses updated successfully')),
        );
      }
    } catch (e) {
      print('Error saving addresses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update addresses')),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _addressControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addAddressField() {
    setState(() {
      _addressControllers.add(TextEditingController());
    });
  }

  void _removeAddressField(int index) {
    setState(() {
      _addressControllers[index].dispose();
      _addressControllers.removeAt(index);
      if (_currentAddressIndex >= _addressControllers.length) {
        _currentAddressIndex = _addressControllers.length - 1;
      }
    });
  }

  void _setAsCurrentAddress(int index) {
    setState(() {
      _currentAddressIndex = index; // Only change the index, no swapping
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Shopping Addresses',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            ..._addressControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return GestureDetector(
                onTap: () => _setAsCurrentAddress(index),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildAddressField(
                        label: _currentAddressIndex == index
                            ? 'Current Shipping Address'
                            : 'Shipping Address',
                        controller: controller,
                        isCurrent: _currentAddressIndex == index,
                      ),
                    ),
                    if (_addressControllers.length > 1)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeAddressField(index),
                      ),
                  ],
                ),
              );
            }).toList(),
            SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _addAddressField,
                child: Text('Add New Address',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _saveAddresses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding:
                  EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField({
    required String label,
    required TextEditingController controller,
    bool isCurrent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isCurrent ? Border.all(color: Colors.green, width: 2.0) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.streetAddress,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(Icons.location_on, color: Colors.grey),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}