import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final TextEditingController placeNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String? selectedCategory;
  String? selectedPriceRange;

  Uint8List? selectedImageBytes;
  String? selectedImageName;

  double? latitude;
  double? longitude;

  bool isLoading = false;

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      selectedImageBytes = bytes;
      selectedImageName = image.name;
    });
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied'),
        ),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location selected successfully')),
    );
  }

  Future<void> publishPlace() async {
    final placeName = placeNameController.text.trim();
    final description = descriptionController.text.trim();

    if (placeName.isEmpty ||
        description.isEmpty ||
        selectedCategory == null ||
        selectedPriceRange == null ||
        latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and choose location'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {

      await FirebaseFirestore.instance.collection('places').add({
        'placeName': placeName,
        'description': description,
        'category': selectedCategory,
        'priceRange': selectedPriceRange,
        'imageName': selectedImageName,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      String imageUrl = imageUrlFromInput;

      
      if (selectedImageBytes != null && selectedImageName != null) {
        final fileName =
            'places/${DateTime.now().millisecondsSinceEpoch}_$selectedImageName';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        await ref.putData(selectedImageBytes!);
        imageUrl = await ref.getDownloadURL();
      }

      // Get user name and ID
      final authorId = currentUser.uid;

      // Save place to Firestore
      final placeRef = await FirebaseFirestore.instance
          .collection('places')
          .add({
            'placeName': placeName,
            'authorId': authorId,
            'description': description,
            'category': selectedCategory,
            'priceRange': selectedPriceRange,
            'imageUrl': imageUrl,
            'imageName': selectedImageName,
            'latitude': latitude,
            'longitude': longitude,
            'rating': 0.0,
            'reviewCount': 0,
            'favoredByUsers': [],
            'createdAt': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .set({
            'addedPlaces': FieldValue.arrayUnion([placeRef.id]),
           }, SetOptions(merge: true));

      // Add place ID to user's addedPlaces array
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .update({
            'addedPlaces': FieldValue.arrayUnion([placeRef.id]),
          })
          .catchError((e) {
            // If user document doesn't exist, create it with addedPlaces
            return FirebaseFirestore.instance
                .collection('users')
                .doc(authorId)
                .set({
                  'addedPlaces': [placeRef.id],
                }, SetOptions(merge: true));
          });


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place published successfully')),
      );

      placeNameController.clear();
      descriptionController.clear();

      setState(() {
        selectedCategory = null;
        selectedPriceRange = null;
        selectedImageBytes = null;
        selectedImageName = null;
        latitude = null;
        longitude = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error publishing place: $e')));
    }

    setState(() {
      isLoading = false;
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
    final hasLocation = latitude != null && longitude != null;

    final LatLng mapCenter = hasLocation
        ? LatLng(latitude!, longitude!)
        : const LatLng(30.0444, 31.2357); // Cairo default

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 219, 219, 219),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Add Place',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
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
                const Text(
                  'Place Name',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

                const Text(
                  'Description',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

                const Text(
                  'Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                    DropdownMenuItem(value: 'Cafe', child: Text('Cafe')),
                    DropdownMenuItem(value: 'Hotel', child: Text('Hotel')),
                    DropdownMenuItem(value: 'Museum', child: Text('Museum')),
                    DropdownMenuItem(
                      value: 'Hidden Gem',
                      child: Text('Hidden Gem'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                ),

                const SizedBox(height: 25),

                const Text(
                  'Price Range',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                    DropdownMenuItem(value: '\$', child: Text('\$')),
                    DropdownMenuItem(value: '\$\$', child: Text('\$\$')),
                    DropdownMenuItem(value: '\$\$\$', child: Text('\$\$\$')),
                    DropdownMenuItem(
                      value: '\$\$\$\$',
                      child: Text('\$\$\$\$'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedPriceRange = value;
                    });
                  },
                ),

                const SizedBox(height: 25),

                const Text(
                  'Upload Images / Videos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                InkWell(
                  onTap: pickImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.shade100,
                    ),
                    child: selectedImageBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, size: 45),
                              SizedBox(height: 10),
                              Text(
                                'Tap to upload',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              selectedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                  ),
                ),

                if (selectedImageName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    selectedImageName!,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],

                const SizedBox(height: 25),

                const Text(
                  'Location Picker',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: mapCenter,
                            initialZoom: hasLocation ? 15 : 12,
                            onTap: (tapPosition, point) {
                              setState(() {
                                latitude = point.latitude;
                                longitude = point.longitude;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Location pinned on map'),
                                ),
                              );
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.likealocal',
                            ),
                            if (hasLocation)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: mapCenter,
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.location_on,
                                      size: 45,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        Positioned(
                          top: 10,
                          right: 10,
                          child: ElevatedButton.icon(
                            onPressed: getCurrentLocation,
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const Text('Use current'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color.fromARGB(
                                255,
                                100,
                                100,
                                100,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (hasLocation) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the map or use current location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color.fromRGBO(158, 158, 158, 1),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 219, 219, 219),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: isLoading ? null : publishPlace,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Publish Place',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 0, 0, 0),
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
