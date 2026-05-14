import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final TextEditingController placeNameController =
      TextEditingController();

  final TextEditingController descriptionController =
      TextEditingController();

  String? selectedCategory;
  String? selectedPriceRange;

  Future<void> publishPlace() async {
    final placeName = placeNameController.text.trim();

    final description = descriptionController.text.trim();

    if (placeName.isEmpty ||
        description.isEmpty ||
        selectedCategory == null ||
        selectedPriceRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
        ),
      );

      return;
    }

    await FirebaseFirestore.instance.collection('places').add({
      'placeName': placeName,
      'description': description,
      'category': selectedCategory,
      'priceRange': selectedPriceRange,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Place published successfully'),
      ),
    );

    placeNameController.clear();
    descriptionController.clear();

    setState(() {
      selectedCategory = null;
      selectedPriceRange = null;
    });
  }

  @override
  void dispose() {
    placeNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8EEEE),
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Add Place',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Center(
        child: SizedBox(
          width: 390,

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                /// PLACE NAME
                const Text(
                  'Place Name',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: placeNameController,

                  decoration: InputDecoration(
                    hintText: 'Enter place name',

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                /// DESCRIPTION
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: descriptionController,
                  maxLines: 5,

                  decoration: InputDecoration(
                    hintText: 'Write a description...',

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                /// CATEGORY
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedCategory,

                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  hint: const Text('Select category'),

                  items: const [
                    DropdownMenuItem(
                      value: 'Restaurant',
                      child: Text('Restaurant'),
                    ),

                    DropdownMenuItem(
                      value: 'Cafe',
                      child: Text('Cafe'),
                    ),

                    DropdownMenuItem(
                      value: 'Hotel',
                      child: Text('Hotel'),
                    ),

                    DropdownMenuItem(
                      value: 'Museum',
                      child: Text('Museum'),
                    ),
                  ],

                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                ),

                const SizedBox(height: 25),

                /// PRICE RANGE
                const Text(
                  'Price Range',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedPriceRange,

                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  hint: const Text('Select price range'),

                  items: const [
                    DropdownMenuItem(
                      value: '\$',
                      child: Text('\$'),
                    ),

                    DropdownMenuItem(
                      value: '\$\$',
                      child: Text('\$\$'),
                    ),

                    DropdownMenuItem(
                      value: '\$\$\$',
                      child: Text('\$\$\$'),
                    ),
                  ],

                  onChanged: (value) {
                    setState(() {
                      selectedPriceRange = value;
                    });
                  },
                ),

                const SizedBox(height: 25),

                /// UPLOAD
                const Text(
                  'Upload Images / Videos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  height: 180,
                  width: double.infinity,

                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),

                    borderRadius: BorderRadius.circular(20),

                    color: Colors.grey.shade100,
                  ),

                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 45,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Tap to upload',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                /// LOCATION
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  height: 180,
                  width: double.infinity,

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),

                    color: Colors.grey.shade200,
                  ),

                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.location_on,
                        size: 45,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Choose location on map',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 60,

                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8E6EA),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),

                    onPressed: publishPlace,

                    child: const Text(
                      'Publish Place',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A4D61),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}