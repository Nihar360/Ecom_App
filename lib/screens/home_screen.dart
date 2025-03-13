import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:naik/screens/product_details_screen.dart';
import 'package:naik/screens/basket_screen.dart';
import 'package:naik/screens/slide_menu.dart';
import 'package:naik/screens/profile_page.dart';
import 'LikedProductsScreen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'All';
  List<Category> _categories = [];
  bool _isLoadingCategories = true;
  int _selectedIndex = 0;
  final double _iconSize = 24.0;
  final double _smallIconSize = 20.0;

  // Search related variables
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  List<Map<String, dynamic>> _allProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchAllProducts();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      QuerySnapshot snapshot = await _firestore.collection('categories').get();
      _categories = snapshot.docs.map((doc) {
        return Category(
          id: doc.id,
          name: doc['name'] ?? 'Unknown',
          icon: doc['icon'] ?? 'https://via.placeholder.com/50',
        );
      }).toList();

      _categories.insert(0, Category(id: 'all', name: 'All', icon: ''));

      setState(() {
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchAllProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('products').get();
      _allProducts = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'] ?? 'Unknown',
          'category': doc['category'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching products for search: $e');
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions.clear();
      });
      return;
    }

    setState(() {
      _searchSuggestions = _allProducts
          .where((product) => product['name'].toLowerCase().contains(query))
          .map((product) => product['name'] as String)
          .toList();
      _showSuggestions = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 5),
            Text(
              'NAIK & SONS',
              style: TextStyle(
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      drawer: SlideMenu(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBar(),
                if (_showSuggestions) _buildSuggestions(),
                SizedBox(height: 30),
                _buildCategoryBar(),
                SizedBox(height: 30),
                ProductsGrid(
                  selectedCategory: _selectedCategory,
                  searchQuery: _searchController.text,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: Icon(
                Icons.home,
                size: _selectedIndex == 0 ? _smallIconSize : _iconSize,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: Icon(
                Icons.favorite_border,
                size: _selectedIndex == 1 ? _smallIconSize : _iconSize,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: _selectedIndex == 2 ? _smallIconSize : _iconSize,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: Icon(
                Icons.person_outline,
                size: _selectedIndex == 3 ? _smallIconSize : _iconSize,
              ),
            ),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LikedProductsScreen()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BasketScreen()),
              );
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: _searchSuggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_searchSuggestions[index]),
            onTap: () {
              _searchController.text = _searchSuggestions[index];
              setState(() {
                _showSuggestions = false;
              });
              FocusScope.of(context).unfocus();
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryBar() {
    if (_isLoadingCategories) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _CategoryItem(
              category: category,
              isSelected: _selectedCategory == category.name,
              onTap: () {
                setState(() {
                  _selectedCategory = category.name;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    Key? key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  _CategoryItemState createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? Colors.deepPurpleAccent.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipOval(
                  child: Image.network(
                    widget.category.icon,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset('assets/all.png', width: 50, height: 50),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.category.name,
              style: TextStyle(
                  fontSize: 16,
                  color: widget.isSelected
                      ? Colors.deepPurpleAccent
                      : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductsGrid extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String selectedCategory;
  final String searchQuery;

  ProductsGrid({required this.selectedCategory, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query;

    if (selectedCategory == 'All') {
      query = _firestore.collection('products');
    } else {
      query = _firestore
          .collection('products')
          .where('category', isEqualTo: selectedCategory);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading products'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No products available'));
        }

        var products = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          products = products.where((product) {
            return product['name']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
          }).toList();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            var product = products[index];
            return _buildProductCard(context, product);
          },
        );
      },
    );
  }

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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
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
                          borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                          child: Image.network(
                            product['images'][0] ??
                                'https://via.placeholder.com/300',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                    'assets/all.png', width: 50, height: 50),
                          ),
                        ),
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
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: Colors.black87),
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
                                  color: Colors.deepPurpleAccent,
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
                        if (product['price'] != null &&
                            product['offerPrice'] != null)
                          _buildDiscountPercentage(
                              product['price'], product['offerPrice']),
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
    double original =
    (originalPrice is int) ? originalPrice.toDouble() : originalPrice;
    double offer = (offerPrice is int) ? offerPrice.toDouble() : offerPrice;

    double discountPercentage = ((original - offer) / original) * 100;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(6),
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
}

class Category {
  final String id;
  final String name;
  final String icon;

  Category({required this.id, required this.name, required this.icon});
}