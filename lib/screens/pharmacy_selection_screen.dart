import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/screens/pharmacy_profile_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';


class PharmacySelectionScreen extends StatefulWidget {
  const PharmacySelectionScreen({super.key});

  @override
  State<PharmacySelectionScreen> createState() => _PharmacySelectionScreenState();
}

class _PharmacySelectionScreenState extends State<PharmacySelectionScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  List<Pharmacy> _allPharmacies = [];
  List<Pharmacy> _filteredPharmacies = [];
  bool _isLoading = true;
  String? _errorMessage;

  Position? _currentPosition;
  bool _locationPermissionGranted = false;

  // Fallback filter state
  String? _selectedCityOrZone;
  List<String> _citiesAndZones = [];

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initLocationAndFetchPharmacies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _applyFilters();
  }

  Future<void> _initLocationAndFetchPharmacies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoading = false;
        });
        return;
      }

      _locationPermissionGranted = true;
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Fetch pharmacies
      _allPharmacies = await _pharmacyService.getPharmacies();

      // Extract unique locations for fallback
      final Set<String> uniqueLocations = {};
      for (var p in _allPharmacies) {
        if (p.city.isNotEmpty) uniqueLocations.add(p.city.trim());
        if (p.zone.isNotEmpty) uniqueLocations.add(p.zone.trim());
      }
      _citiesAndZones = uniqueLocations.toList()..sort();

      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de chargement: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showGPSDisabledDialog() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "GPS désactivé",
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: LightModeColors.lightErrorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      color: LightModeColors.lightError,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "GPS désactivé",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Votre GPS semble être désactivé. Veuillez l'activer dans les paramètres de votre téléphone pour utiliser cette fonctionnalité.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: LightModeColors.novoPharmaGray,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: LightModeColors.novoPharmaBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Annuler",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await Geolocator.openLocationSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.novoPharmaBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Paramètres",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showGPSDisabledDialog();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Error checking location permission: $e");
      return false;
    }
  }

  void _applyFilters() {
    List<Pharmacy> temp = [];

    // 1. Filter by location / city
    if (_selectedCityOrZone != null && _selectedCityOrZone!.isNotEmpty) {
      temp = _allPharmacies.where((pharmacy) {
        return pharmacy.city.trim() == _selectedCityOrZone || pharmacy.zone.trim() == _selectedCityOrZone;
      }).toList();
    } else {
      if (_locationPermissionGranted && _currentPosition != null) {
        final double userLat = _currentPosition!.latitude;
        final double userLng = _currentPosition!.longitude;
        temp = _allPharmacies.where((pharmacy) {
          if (pharmacy.location.latitude == 0.0 && pharmacy.location.longitude == 0.0) {
            return false;
          }
          double distanceInMeters = Geolocator.distanceBetween(
            userLat,
            userLng,
            pharmacy.location.latitude,
            pharmacy.location.longitude,
          );
          return distanceInMeters <= 1000.0;
        }).toList();
      } else {
        temp = List.from(_allPharmacies);
      }
    }

    // 2. Filter by search query
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((pharmacy) {
        return pharmacy.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               pharmacy.address.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredPharmacies = temp;
    });
  }

  void _filterByCityOrZone(String? value) {
    setState(() {
      _selectedCityOrZone = value;
    });
    _applyFilters();
  }

  Future<void> _handleCheckIn(Pharmacy pharmacy) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session utilisateur introuvable")),
      );
      return;
    }

    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Confirmation",
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: LightModeColors.novoPharmaLightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pin_drop_rounded,
                      color: LightModeColors.novoPharmaBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Confirmer le Check-in",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Voulez-vous enregistrer votre Check-in à la pharmacie :\n\n\"${pharmacy.name}\" ?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: LightModeColors.novoPharmaGray,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: LightModeColors.novoPharmaBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Annuler",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.novoPharmaBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Confirmer",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      GeoPoint checkInGeoPoint = const GeoPoint(0, 0);
      try {
        if (_locationPermissionGranted) {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          checkInGeoPoint = GeoPoint(pos.latitude, pos.longitude);
        }
      } catch (e) {
        debugPrint("Error fetching exact check-in location: $e");
      }

      final docRef = FirebaseFirestore.instance.collection('visits_history').doc();
      final visitId = docRef.id;

      final checkInData = {
        'visitId': visitId,
        'dermoId': user.uid,
        'pharmacyId': pharmacy.id,
        'pharmacyName': pharmacy.name,
        'checkInLocation': checkInGeoPoint,
        'checkInTime': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'status': 'active',
      };

      await docRef.set(checkInData);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_visit_id', visitId);
      await prefs.setString('active_pharmacy_id', pharmacy.id);
      await prefs.setString('active_pharmacy_name', pharmacy.name);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PharmacyProfileScreen(
              pharmacyId: pharmacy.id,
              pharmacyName: pharmacy.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du Check-in: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationScaffoldWrapper(
      currentIndex: 0,
      onTap: (index) {},
      child: Scaffold(
        backgroundColor: LightModeColors.novoPharmaLightGray,
        appBar: AppBar(
        title: const Text(
          "Sélection Pharmacie",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: LightModeColors.dashboardTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_locationPermissionGranted
              ? _buildGPSBlocker()
              : Column(
                  children: [
                    // Premium Header Banner
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          // Dropdown selector
                          DropdownSearch<String>(
                            items: (filter, loadProps) {
                              final list = ["Sélectionner à proximité (GPS)", ..._citiesAndZones];
                              if (filter.isEmpty) return list;
                              return list.where((item) => item.toLowerCase().contains(filter.toLowerCase())).toList();
                            },
                            selectedItem: _selectedCityOrZone ?? "Sélectionner à proximité (GPS)",
                            decoratorProps: DropDownDecoratorProps(
                              decoration: InputDecoration(
                                hintText: "Filtrer par Ville / Zone",
                                hintStyle: const TextStyle(color: LightModeColors.novoPharmaGray, fontSize: 14),
                                prefixIcon: const Icon(Icons.filter_alt_outlined, color: LightModeColors.novoPharmaBlue, size: 20),
                                filled: true,
                                fillColor: LightModeColors.novoPharmaLightGray,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: LightModeColors.lightOutlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: LightModeColors.lightOutlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              fit: FlexFit.loose,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: "Rechercher...",
                                  prefixIcon: const Icon(Icons.search, color: LightModeColors.novoPharmaBlue),
                                  filled: true,
                                  fillColor: LightModeColors.novoPharmaLightGray,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                              menuProps: MenuProps(
                                borderRadius: BorderRadius.circular(16),
                                elevation: 8,
                              ),
                              itemBuilder: (context, item, isSelected, isHighlighted) {
                                final isGps = item == "Sélectionner à proximité (GPS)";
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? LightModeColors.novoPharmaLightBlue 
                                        : (isHighlighted ? Colors.grey.shade50 : null),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isGps ? Icons.gps_fixed : Icons.location_city,
                                        color: isSelected 
                                            ? LightModeColors.novoPharmaBlue 
                                            : LightModeColors.novoPharmaGray,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected 
                                                ? LightModeColors.novoPharmaBlue 
                                                : LightModeColors.dashboardTextPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: LightModeColors.novoPharmaBlue,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            onChanged: (String? value) {
                              if (value == "Sélectionner à proximité (GPS)") {
                                _filterByCityOrZone(null);
                              } else {
                                _filterByCityOrZone(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          // Search bar
                          Material(
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: "Rechercher une pharmacie...",
                                hintStyle: const TextStyle(
                                  color: LightModeColors.novoPharmaGray,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: LightModeColors.novoPharmaBlue,
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: LightModeColors.novoPharmaGray,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: LightModeColors.lightOutlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: LightModeColors.lightOutlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        children: [
                          Icon(
                            _selectedCityOrZone != null ? Icons.map : Icons.my_location,
                            size: 18,
                            color: LightModeColors.novoPharmaBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCityOrZone != null
                                ? "Pharmacies à $_selectedCityOrZone"
                                : "Pharmacies à moins de 1 km",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List view of pharmacies
                    Expanded(
                      child: _errorMessage != null
                          ? Center(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: LightModeColors.lightError),
                              ),
                            )
                          : _filteredPharmacies.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      "Aucune pharmacie à proximité.\nVeuillez filtrer par Ville/Zone.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: LightModeColors.novoPharmaGray, height: 1.4),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                                  itemCount: _filteredPharmacies.length,
                                  itemBuilder: (context, index) {
                                    final pharmacy = _filteredPharmacies[index];
                                    double? dist;
                                    if (_locationPermissionGranted &&
                                        _currentPosition != null &&
                                        pharmacy.location.latitude != 0.0 &&
                                        pharmacy.location.longitude != 0.0) {
                                      dist = Geolocator.distanceBetween(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                        pharmacy.location.latitude,
                                        pharmacy.location.longitude,
                                      );
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.02),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(color: LightModeColors.lightOutlineVariant),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            dividerColor: Colors.transparent,
                                          ),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            leading: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: LightModeColors.novoPharmaLightBlue,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.local_hospital_rounded,
                                                color: LightModeColors.novoPharmaBlue,
                                                size: 24,
                                              ),
                                            ),
                                            title: Text(
                                              pharmacy.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: LightModeColors.dashboardTextPrimary,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 6),
                                                Text(
                                                  pharmacy.address.isNotEmpty ? pharmacy.address : "Pas d'adresse spécifiée",
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: LightModeColors.novoPharmaGray,
                                                  ),
                                                ),
                                                if (dist != null) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: LightModeColors.novoPharmaLightBlue,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.directions_walk,
                                                          size: 12,
                                                          color: LightModeColors.novoPharmaBlue,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          dist < 1000
                                                              ? "${dist.toStringAsFixed(0)} m"
                                                              : "${(dist / 1000).toStringAsFixed(1)} km",
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: LightModeColors.novoPharmaBlue,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            trailing: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: LightModeColors.novoPharmaLightGray,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.login_rounded,
                                                size: 18,
                                                color: LightModeColors.novoPharmaBlue,
                                              ),
                                            ),
                                            onTap: () => _handleCheckIn(pharmacy),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    ),
    );
  }

  Widget _buildGPSBlocker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: LightModeColors.lightError.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: LightModeColors.lightError,
                size: 56,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              "Localisation GPS Requise",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "L'accès à la position GPS de votre téléphone est requis pour utiliser le Check-in / Check-out.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: LightModeColors.novoPharmaGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _initLocationAndFetchPharmacies,
                icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                label: const Text(
                  "Autoriser / Réessayer",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.novoPharmaBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
