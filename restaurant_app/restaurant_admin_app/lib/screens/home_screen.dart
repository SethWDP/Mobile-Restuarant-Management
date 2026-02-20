import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../model/food_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Food>> _foodsFuture;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  final String baseUrl = "http://10.0.2.2:3000/api/foods";

  @override
  void initState() {
    super.initState();
    _foodsFuture = fetchFoods();
  }

  Future<List<Food>> fetchFoods() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Food.fromJson(data)).toList();
      }
      throw Exception("Fetch failed");
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }

  // --- DELETE ---
  Future<void> _deleteFood(int id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));
      if (response.statusCode == 200) {
        setState(() {
          _foodsFuture = fetchFoods(); // Refresh list after delete
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- ADD / UPDATE ---
  Future<void> _processFood({
    Food? food, // If null, we ADD. If not null, we UPDATE.
    required String name,
    required double price,
    required String category,
    required String description,
  }) async {
    var request = http.MultipartRequest(
      food == null ? 'POST' : 'PUT',
      Uri.parse(food == null ? baseUrl : "$baseUrl/${food.id}"),
    );

    request.fields['name'] = name;
    request.fields['price'] = price.toString();
    request.fields['category'] = category;
    request.fields['description'] = description;

    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path),
      );
    }

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      setState(() {
        _foodsFuture = fetchFoods();
        _imageFile = null; // Clear image after success
      });
      if (mounted) Navigator.pop(context);
    }
  }

  // --- POPUP  (Works for both Add and Edit) ---
  void _showAddPopup({Food? food}) {
    final nameController = TextEditingController(text: food?.name ?? "");
    final priceController = TextEditingController(
      text: food?.price.toString() ?? "",
    );
    final descController = TextEditingController(text: food?.description ?? "");
    String selectedCategory =
        (food != null &&
            (food.category == 'Main' || food.category == 'Beverages'))
        ? food.category
        : 'Main';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(food == null ? "Add New Item" : "Edit Item"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- IMAGE INPUT SECTION ---
                    GestureDetector(
                      onTap: () async {
                        final XFile? pickedFile = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (pickedFile != null) {
                          // This updates the UI inside the dialog
                          setDialogState(
                            () => _imageFile = File(pickedFile.path),
                          );
                        }
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : (food != null && food.imageUrl.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  food.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                  Text(
                                    "Tap to select image",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // --- TEXT INPUTS ---
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Dish Name"),
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: "Description",
                      ),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Price (\$)",
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: ['Main', 'Beverages']
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedCategory = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _imageFile = null; // Reset image on cancel
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _processFood(
                      food: food,
                      name: nameController.text,
                      price: double.tryParse(priceController.text) ?? 0.0,
                      category: selectedCategory,
                      description: descController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                  ),
                  child: Text(
                    food == null ? "Add" : "Update",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFoodList(List<Food> foods, String filter) {
    final filteredList = filter == "All"
        ? foods
        : foods.where((f) => f.category == filter).toList();

    const red = Color(0xFFD32F2F);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final food = filteredList[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE (left)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  food.imageUrl,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 110,
                    height: 110,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.fastfood,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // RIGHT CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE + CATEGORY CHIP
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            food.category, // shows Main / Beverages
                            style: const TextStyle(
                              color: Color(0xFFB8860B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // DESCRIPTION
                    Text(
                      food.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // PRICE
                    Text(
                      "\$ ${food.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // BUTTONS ROW
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showAddPopup(food: food),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Edit",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _deleteFood(food.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: red,
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Delete",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFD32F2F);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: red,
          elevation: 0,
          toolbarHeight: 88,
          titleSpacing: 16,
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Restaurant App",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Admin",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: red,
                  borderRadius: BorderRadius.circular(18),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: "All"),
                  Tab(text: "Foods"),
                  Tab(text: "Beverages"),
                ],
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Food>>(
          future: _foodsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            return TabBarView(
              children: [
                _buildFoodList(snapshot.data!, "All"),
                _buildFoodList(snapshot.data!, "Main"),
                _buildFoodList(snapshot.data!, "Beverages"),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: red,
          onPressed: () => _showAddPopup(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
