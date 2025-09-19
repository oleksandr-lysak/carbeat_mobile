import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/pages/home/map_view/master_dialog.dart';
import 'package:carbeat/services/fcm_service.dart';
import 'package:carbeat/widgets/loading.dart';
import 'package:carbeat/widgets/map_card.dart';
import 'package:carbeat/services/location_service.dart';
import 'package:carbeat/services/animation_service.dart';
import 'package:carbeat/widgets/pulsaring_master.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../../classes/garage_marker.dart';
import '../../models/master.dart';
import '../../services/language_service.dart';
import 'package:carbeat/widgets/animated_dropdown_field.dart';
import 'package:carbeat/providers/service_provider.dart';
import 'package:carbeat/widgets/map_filter_dialog.dart';
import 'package:carbeat/widgets/user_location_marker.dart';
import 'dart:async';
import '../../utils/parse_utils.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:carbeat/widgets/cluster_circle.dart';
import 'package:carbeat/widgets/master_profile_sheet.dart';
import 'package:carbeat/navigation/route_observer.dart';
import 'package:carbeat/widgets/master_registration_flow_sheet.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:carbeat/widgets/app_toast.dart';
 
 
 class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  MapViewState createState() => MapViewState();
}

class MapViewState extends State<MapView> with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  final pageController = PageController();
  static final MapController mapController = MapController();
  final DraggableScrollableController sheetController =
      DraggableScrollableController();
  late AnimationController _animationController;
  List<Master> mapMasters = [];
  List<GarageMarker> masters = [];
  LatLng? currentLocation;
  int selectedIndex = -1;
  bool loading = true;
  int totalPages = 1;
  int currentPage = 1;
  bool mapWasLoaded = false;

  String? filterName;
  double? filterRating;
  bool? filterAvailable;
  int? filterServiceId;
  String? sortBy;

  DropdownItem? selectedService;
  TextEditingController nameController = TextEditingController();
  double? selectedRating;
  bool? selectedAvailable;
  String? selectedSort;

  Timer? _refreshTimer;
  static const Duration refreshInterval = Duration(seconds: 15);

  // This flag is used to distinguish between PageView scrolls that are
  // triggered programmatically after tapping on a marker (animateToPage)
  // and scrolls that are initiated manually by the user. While the page is
  // animating we ignore onPageChanged callbacks to avoid an additional
  // _onMarkerTap invocation which could lead to the map centering on a wrong
  // master.
  bool _isPageAnimating = false;

  // Indicates whether the current logged-in user has a linked master profile.
  bool _isMaster = false;
  String? _masterPhoto;
  bool _isAvailable = false;

  // Cached zoom level so we can detect threshold crossings.
  double _currentZoom = 0;

  // Guard to suppress page change handling while we refresh/rebuild lists
  bool _isRefreshing = false;
  bool _softRefreshing = false;

  // Masters that should currently be shown on the map after applying zoom-based
  // filtering rules.
  List<Master> visibleMasters = [];
  
  int? _selectedMasterId;
  
  late final StreamSubscription _mapSub;
  bool _isRouteVisible = false;
  bool _isRouteSubscribed = false;
  
  // Threshold: show detailed markers above this zoom, blue dots otherwise
  static const double _markerDetailZoomThreshold = 15.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ServiceProvider>(context, listen: false).loadSpecialties();
    });
    WidgetsBinding.instance.addObserver(this);
    _initLocationAndLoadData();

    // Check whether the current user is a master so that we can optionally
    // display additional UI (e.g. the "Become available" button).
    _updateMasterStatus();

    // Listen for map movements/zoom changes to update visible masters.
    _mapSub = MapViewState.mapController.mapEventStream.listen((event) {
      _updateVisibleMasters();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_isRouteSubscribed && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteSubscribed = true;
      _isRouteVisible = true;
      _startRefreshTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isRouteVisible) {
        _startRefreshTimer();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopRefreshTimer();
    }
  }

  @override
  void didPush() {
    _isRouteVisible = true;
    _startRefreshTimer();
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
    _startRefreshTimer();
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
    _stopRefreshTimer();
  }

  @override
  void didPop() {
    _isRouteVisible = false;
    _stopRefreshTimer();
  }

  Future<void> _initLocationAndLoadData() async {
    final location = await LocationService.getCurrentLocation();
    setState(() {
      currentLocation = location;
    });
    await _loadMapData(location);

    // Initial filtering once data is loaded.
    _updateVisibleMasters();
  }

  Future<List<Master>> getData(
    double longitude,
    double latitude,
    int page,
    double zoom,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Geolocator.checkPermission();
    }

    String serverUrl = AppConstants.serverUrl;
    final String locale = await LanguageService.getLanguage() ?? 'en';
    final fcmToken = await FCMService.getToken();
    Map<String, dynamic> params = {
      'lng': longitude,
      'lat': latitude,
      'zoom': zoom,
      'page': page,
      'locale': locale,
      'fcm_token': fcmToken,
    };
    if (filterName != null && filterName!.isNotEmpty) {
      params['name'] = filterName;
    }
    if (filterRating != null) params['rating'] = filterRating;
    if (filterAvailable != null) params['available'] = filterAvailable! ? 1 : 0;
    if (filterServiceId != null) params['service_id'] = filterServiceId;
    if (sortBy != null && sortBy!.isNotEmpty) params['sort'] = sortBy;

    String url = '${serverUrl}masters?';
    url += params.entries.map((e) => "${e.key}=${e.value}").join('&');

    try {
      Response response = await dio.get('$url&per_page=1000');
    apiData = response.data;
    } on DioException catch (_) {
      if (!mounted) return [];
      setState(() {
        loading = false;
      });
      AppToast.show('Сервер тимчасово недоступний. Спробуйте пізніше.', background: Colors.red);
      return [];
    } catch (_) {
      if (!mounted) return [];
      setState(() {
        loading = false;
      });
      AppToast.show('Виникла помилка під час завантаження.', background: Colors.red);
      return [];
    }
    
    var tagObjsJson = apiData["data"] as List;
    List<Master> tagObjs = await compute(parseMasters, tagObjsJson);
    mapWasLoaded = true;
    return tagObjs;
  }

  Future<void> _loadMapData(LatLng position) async {
    double zoom = 13;

    final stopwatch = Stopwatch()..start();
    if (totalPages >= 1) {
      await _fetchMarkers(
        position.longitude,
        position.latitude,
        currentPage,
        zoom,
        updateImmediately: true,
      );
    }
    stopwatch.stop();

    if (totalPages > 1) {
      List<Future<List<Master>>> fetchRequests = [];

      for (int page = 2; page <= totalPages; page++) {
        fetchRequests.add(
          getData(position.longitude, position.latitude, page, zoom),
        );
      }

      List<List<Master>> results = await Future.wait(fetchRequests);

      setState(() {
        for (var masters in results) {
          mapMasters.addAll(masters);
        }
        _updateVisibleMasters();
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _fetchMarkers(
    double longitude,
    double latitude,
    int page,
    double zoom, {
    bool updateImmediately = false,
  }) async {
    final masters = await getData(longitude, latitude, page, zoom);
    setState(() {
      mapMasters.addAll(masters);
      if (page == 1) {
        totalPages = masters.isNotEmpty ? apiData["meta"]["last_page"] : 1;
      }

      if (updateImmediately) {
        _updateVisibleMasters();
        loading = false;
      }
    });
  }

  void _createMarkers() {
    masters = [];
    final Set<int> seenMasterIds = {};
    final double zoom = _controllerReady() ? mapController.camera.zoom : 12;
    final bool zoomAllowsDetail = zoom > _markerDetailZoomThreshold;
    GarageMarker? selectedMarker;
    for (int i = 0; i < visibleMasters.length; i++) {
      final master = visibleMasters[i];
      if (seenMasterIds.contains(master.id)) continue;
      seenMasterIds.add(master.id);
      final bool isActive = i == selectedIndex;
      final double markerSize = (master.available || zoomAllowsDetail)
          ? (isActive ? 52.0 : 40.0)
          : (isActive ? 20.0 : 12.0);
      final marker = GarageMarker(
        key: ValueKey('marker_${master.id}'),
        height: markerSize,
        width: markerSize,
        point: master.location,
        master: master,
        child: GestureDetector(
          onTap: () {
            _onMarkerTap(i);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: (master.available || zoomAllowsDetail)
                ? Container(
                    key: ValueKey('detailed_${master.id}_${master.available ? 1 : 0}'),
                    child: AnimatedScale(
                      scale: isActive ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isActive)
                            Container(
                              width: markerSize * 1.4,
                              height: markerSize * 1.4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blueAccent.withOpacity(0.25),
                              ),
                            ),
                          if (isActive)
                            Container(
                              width: markerSize * 1.05,
                              height: markerSize * 1.05,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          PulsatingMaster(
                            master: master,
                            isActive: isActive,
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    key: ValueKey('dot_${master.id}_${master.available ? 1 : 0}'),
                    child: Center(
                      child: _BouncingDot(
                        size: markerSize,
                        color: Colors.blue,
                        isActive: isActive,
                        bounce: false,
                      ),
                    ),
                  ),
          ),
        ),
      );

      if (isActive) {
        selectedMarker = marker;
      } else {
      masters.add(marker);
      }
    }
    if (selectedMarker != null) {
      masters.add(selectedMarker!);
    }
  }

  int _countMastersInViewport() {
    if (!_controllerReady()) return masters.length;
    try {
      final bounds = mapController.camera.visibleBounds;
      int count = 0;
      for (final m in visibleMasters) {
        if (bounds.contains(m.location)) count++;
      }
      return count;
    } catch (_) {
      return masters.length;
    }
  }

  void _onMarkerTap(int index) {
    // Prevent out-of-range errors that may happen right after a list refresh.
    if (index < 0 || index >= visibleMasters.length) return;

    setState(() {
      selectedIndex = index;
      _selectedMasterId = visibleMasters[index].id;
      _createMarkers();
    });
  }
  
  void _clearSelection() {
    if (_selectedMasterId != null || selectedIndex != -1) {
      setState(() {
        _selectedMasterId = null;
        selectedIndex = -1;
        _createMarkers();
      });
    }
  }

  void _moveToCurrentLocation() {
    if (currentLocation == null) return;
    AnimationService.animatedMapMove(
      mapController,
      _animationController,
      currentLocation!,
      18,
    );
  }

  void _showList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Styles().primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final mastersToShow = List<Master>.from(visibleMasters);
        // Compute distance (km) from current location and sort: available first, then by distance asc
        final Distance distanceCalc = Distance();
        final List<Map<String, dynamic>> items = mastersToShow.map((m) {
          final double km = (currentLocation != null)
              ? distanceCalc.as(LengthUnit.Kilometer, currentLocation!, m.location)
              : double.infinity;
          return {'master': m, 'km': km, 'available': m.available};
        }).toList();
        items.sort((a, b) {
          final bool aAvail = a['available'] as bool;
          final bool bAvail = b['available'] as bool;
          if (aAvail != bAvail) return aAvail ? -1 : 1;
          return (a['km'] as double).compareTo(b['km'] as double);
        });
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        'Masters (${items.length})',
                        style:  TextStyle(fontSize: 20, fontWeight: FontWeight.w600, 
                        color: Styles().titleColor),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Styles().titleColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final m = items[index]['master'] as Master;
                      final double km = items[index]['km'] as double;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          foregroundImage: (m.mainPhoto.isNotEmpty)
                              ? NetworkImage(_buildPhotoUrl(m.mainPhoto))
                              : null,
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                        title: Text(m.name, style: TextStyle(color: Styles().titleColor)),
                        subtitle: Row(
                          children: [
                            if (m.available)
                               Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.circle, color: Styles().checkColor, size: 10),
                              ),
                            Flexible(
                              child: 
                              Text('~${km.isFinite ? km.toStringAsFixed(2) : '--'} km', 
                              maxLines: 1, overflow: TextOverflow.ellipsis, 
                              style: TextStyle(color: Styles().backgroundFormColor))
                              ),
                            const SizedBox(width: 8),
                            Text('${m.rating.toStringAsFixed(1)}★'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          final idx = visibleMasters.indexWhere((vm) => vm.id == m.id);
                          if (idx != -1) {
                            _onMarkerTap(idx);
                            AnimationService.animatedMapMove(
                              mapController,
                              _animationController,
                              m.location,
                              17,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showFilterDialog() async {
    final serviceProvider = Provider.of<ServiceProvider>(
      context,
      listen: false,
    );
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) {
        return MapFilterDialog(
          services: serviceProvider.services,
          initialName: filterName,
          initialServiceId: filterServiceId,
          initialRating: filterRating,
          initialAvailable: filterAvailable,
          initialSort: sortBy,
          onApply: ({
            String? name,
            int? serviceId,
            double? rating,
            bool? available,
            String? sort,
          }) async {
            setState(() {
              filterName = name;
              filterServiceId = serviceId;
              filterRating = rating;
              filterAvailable = available;
              sortBy = sort;
              mapMasters.clear();
              masters.clear();
              loading = true;
              currentPage = 1;
              _selectedMasterId = null;
              selectedIndex = -1;
            });
            if (currentLocation != null) {
              await _loadMapData(currentLocation!);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const Center(child: Loading());
    }
    return loading
        ? const Center(child: Loading())
        : Scaffold(
          backgroundColor: Styles().titleColor,
          body: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  minZoom: 2,
                  maxZoom: 18,
                  initialZoom: 11,
                  initialCenter: currentLocation!,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (tapPosition, point) {
                    _clearSelection();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    //urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'], // CartoCDN вимагає це
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.it-pragmat.plant',
                    tileProvider: const FMTCStore('mapStore').getTileProvider(),
                  ),
                  // User location marker
                  if (currentLocation != null)
                    UserLocationMarker(location: currentLocation!),
                  // Маркери: кластеризація якщо в межах екрана > 100
                  if (_countMastersInViewport() > 100)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 60,
                        size: const Size(40, 40),
                        markers: masters,
                        builder: (context, clusterMarkers) {
                          final gm = clusterMarkers.whereType<GarageMarker>().toList();
                          return ClusterCircle(markers: gm);
                        },
                      ),
                    )
                  else
                  MarkerLayer(markers: masters),
                ],
                ),
              Positioned(
                right: 10,
                top: MediaQuery.of(context).size.height * 0.05,
                child: FloatingActionButton(
                  onPressed: () {
                    if (_isMaster) {
                      // Open the editable bottom-sheet with master profile details.
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const MasterProfileSheet(),
                      );
                    } else {
                      // Open the phone / OTP dialog. When the user is
                      // successfully authorised as a master we update the UI
                      // to reveal the availability button.
                      showMasterDialog(
                        context,
                        onAuthorized: () {
                          _updateMasterStatus();
                        },
                        onStartRegistration: (phone) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.black.withOpacity(0.35),
                            builder: (_) => MasterRegistrationFlowSheet(
                              phone: phone,
                              parentContext: context,
                            ),
                          ).then((_) {
                            // After registration flow closes, refresh master status
                            _updateMasterStatus();
                          });
                        },
                      );
                    }
                    //Navigator.pushNamed(context, '/map-picker');
                  },
                  backgroundColor: _isMaster && _masterPhoto != null
                      ? Colors.transparent
                      : Styles().primaryColor,
                  elevation: _isMaster && _masterPhoto != null ? 0.0 : 10.0,
                  child: _buildMasterFabChild(),
                ),
              ),
              // Positioned(
              //   right: 250,
              //   top: MediaQuery.of(context).size.height * 0.05,
              //   //bottom: MediaQuery.of(context).size.height * 0.3 + 165,
              //   child: FloatingActionButton(
              //     onPressed: _moveToCurrentLocation,
              //     backgroundColor: Styles().primaryColor,
              //     elevation: 10.0,
              //     child: Icon(Icons.my_location, color: Styles().titleColor),
              //   ),
              // ),
              Positioned(
                left: 10,
                top: MediaQuery.of(context).size.height * 0.05,
                //bottom: MediaQuery.of(context).size.height * 0.3 + 165,
                child: FloatingActionButton(
                  onPressed: _showList,
                  backgroundColor: Styles().primaryColor,
                  elevation: 10.0,
                  child: Icon(Icons.list, color: Styles().titleColor),
                ),
              ),
              Positioned(
                left: 80,
                top: MediaQuery.of(context).size.height * 0.05,
                child: FloatingActionButton(
                  heroTag: 'filter_fab',
                  onPressed: _showFilterDialog,
                  backgroundColor: Styles().primaryColor,
                  elevation: 10.0,
                  child: Icon(Icons.filter_alt, color: Styles().titleColor),
                ),
              ),
              
              // Extra button allowing masters to toggle their availability.
              if (_isMaster)
              Positioned(
                  right: 80,
                  top: MediaQuery.of(context).size.height * 0.05,
                  child: FloatingActionButton.extended(
                    heroTag: 'availability_fab',
                    onPressed: _toggleAvailability,
                      backgroundColor: Styles().primaryColor,
                      elevation: 10.0,
                    icon: Icon(
                      _isAvailable ? Icons.toggle_on : Icons.toggle_off,
                      color: _isAvailable ? Colors.greenAccent : Colors.grey,
                      size: 28,
                    ),
                    label: Text(
                      _isAvailable ? 'Стати зайнятим' : 'Стати доступним',
                      style: TextStyle(color: Styles().titleColor),
                    ),
                  ),
                ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeOutCubic))
                        .animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offsetAnimation, child: child),
                    );
                  },
                  child: (_selectedMasterId != null && visibleMasters.any((m) => m.id == _selectedMasterId))
                      ? DraggableScrollableSheet(
                          key: ValueKey('sheet_${_selectedMasterId}'),
                          maxChildSize: 0.31,
                          initialChildSize: 0.31,
                          minChildSize: 0.07,
                          builder: (BuildContext context, scrollController) {
                            final idx = visibleMasters.indexWhere((m) => m.id == _selectedMasterId);
                            if (idx == -1) {
                              return const SizedBox.shrink();
                            }
                            final master = visibleMasters[idx];
                            return CustomScrollView(
                              controller: scrollController,
                              slivers: [
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.3,
                                    child: Stack(
                                      children: [
                                        MapCard(item: master),
                                        Positioned(
                                          top: 20,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).hintColor,
                                                borderRadius: const BorderRadius.all(
                                                  Radius.circular(
                                                    Styles.borderRadius,
                                                  ),
                                                ),
                                              ),
                                              height: 4,
                                              width: 40,
                                            ),
                                          ),
                    ),
                  ],
                ),
              ),
                                ),
                              ],
                            );
                          },
                        )
                      : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        );
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    if (_isRouteSubscribed) {
      routeObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _mapSub.cancel();
    pageController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) => _softRefreshMasters());
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _softRefreshMasters() async {
    if (currentLocation == null || !mapWasLoaded) return;
    if (!_controllerReady()) return;
    if (_softRefreshing) return;
    _softRefreshing = true;
    final newMasters = await getData(
      currentLocation!.longitude,
      currentLocation!.latitude,
      1,
      mapController.camera.zoom,
    );
    // Якщо на сервері є пагінація — оновлюємо всі сторінки, щоб статуси були актуальні для всіх майстрів
    List<Master> aggregated = List.of(newMasters);
    if (totalPages > 1) {
      final List<Future<List<Master>>> futures = [];
      for (int page = 2; page <= totalPages; page++) {
        futures.add(getData(
          currentLocation!.longitude,
          currentLocation!.latitude,
          page,
          mapController.camera.zoom,
        ));
      }
      final results = await Future.wait(futures);
      for (final list in results) {
        aggregated.addAll(list);
      }
    }

    // Створюємо мапу для швидкого пошуку по id
    final Map<int, Master> newMastersMap = {for (var m in aggregated) m.id: m};
    final Map<int, Master> oldMastersMap = {for (var m in mapMasters) m.id: m};

    // Оновлюємо статуси та дані для існуючих майстрів
    bool changed = false;
    for (int i = 0; i < mapMasters.length; i++) {
      final old = mapMasters[i];
      final updated = newMastersMap[old.id];
      if (updated != null) {
        // Якщо щось змінилося (наприклад, available, location, rating, photo)
        if (old.available != updated.available ||
            old.location != updated.location ||
            old.rating != updated.rating ||
            old.mainPhoto != updated.mainPhoto) {
          mapMasters[i] = updated;
          changed = true;
        }
      } else {
        // Не видаляємо майстрів у soft-refresh, щоб не було стрибків у UI
      }
    }
    // Додаємо нових майстрів
    for (final m in aggregated) {
      if (!oldMastersMap.containsKey(m.id)) {
        mapMasters.add(m);
        changed = true;
      }
    }
    if (changed) {
      _updateVisibleMasters();
    }
    _softRefreshing = false;
  }

  /// Re-evaluates whether the logged-in user is a master and updates the UI.
  Future<void> _updateMasterStatus() async {
    final user = await UserService().getUser();
    if (!mounted) return;
    setState(() {
      _isMaster = user?.master != null;
      _masterPhoto = user?.master?.mainPhoto;
    });
    await _refreshOwnAvailabilityFromServer();
  }

  Future<void> _refreshOwnAvailabilityFromServer() async {
    final user = await UserService().getUser();
    if (user?.master == null) {
      if (!mounted) return;
      setState(() {
        _isAvailable = false;
      });
      return;
    }
    try {
      final api = ApiService(AppConstants.serverUrl);
      final res = await api.getRequest('masters/${user!.master!.id}/availability');
      bool serverAvailable = false;
      if (res is Map) {
        if (res.containsKey('available')) {
          final val = res['available'];
          if (val is bool) serverAvailable = val; else if (val is num) serverAvailable = val != 0; else if (val is String) serverAvailable = val == '1' || val.toLowerCase() == 'true';
        } else if (res.containsKey('availability')) {
          final val = res['availability'];
          if (val is bool) serverAvailable = val; else if (val is num) serverAvailable = val != 0; else if (val is String) serverAvailable = val == '1' || val.toLowerCase() == 'true';
        } else if (res.containsKey('data')) {
          final data = res['data'];
          if (data is Map) {
            if (data.containsKey('available')) {
              final val = data['available'];
              if (val is bool) serverAvailable = val; else if (val is num) serverAvailable = val != 0; else if (val is String) serverAvailable = val == '1' || val.toLowerCase() == 'true';
            } else if (data.containsKey('availability')) {
              final val = data['availability'];
              if (val is bool) serverAvailable = val; else if (val is num) serverAvailable = val != 0; else if (val is String) serverAvailable = val == '1' || val.toLowerCase() == 'true';
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _isAvailable = serverAvailable;
      });
    } catch (_) {
      // Ignore errors; keep previous state
    }
  }

  Future<void> _toggleAvailability() async {
    final user = await UserService().getUser();
    if (user?.master == null) return;
    try {
      final api = ApiService(AppConstants.serverUrl);
      if (_isAvailable) {
        await api.deleteRequest('masters/${user!.master!.id}/availability');
        await _refreshOwnAvailabilityFromServer();
        await _softRefreshMasters();
        if (!mounted) return;
        AppToast.show('Ви стали зайнятими', background: Colors.green,duration: Duration(seconds: 5));
      } else {
        _showAvailabilitySheet();
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show('Не вдалося оновити доступність', background: Colors.red,duration: Duration(seconds: 5));
    }
  }

  void _showAvailabilitySheet() {
    int minutes = 60;
    final TextEditingController ctrl = TextEditingController(text: minutes.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Styles().primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Стати вільним',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Styles().titleColor),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Styles().titleColor,
                        labelText: 'Тривалість (хв)',
                      ),
                      onChanged: (val) {
                        final n = int.tryParse(val);
                        if (n != null && n > 0) minutes = n;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          minutes += 30;
                          ctrl.text = minutes.toString();
                        },
                        child: const Text('+30'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          minutes = (minutes - 30).clamp(30, 24 * 60);
                          ctrl.text = minutes.toString();
                        },
                        child: const Text('-30'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Скасувати', style: TextStyle(color: Styles().titleColor)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final n = int.tryParse(ctrl.text) ?? minutes;
                        final duration = n > 0 ? n : 60;
                        Navigator.pop(ctx);
                        await _setAvailability(duration);
                      },
                      child: Text('Стати вільним', style: TextStyle(color: Styles().titleColor)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setAvailability(int durationMinutes) async {
    final user = await UserService().getUser();
    if (user?.master == null) return;
    try {
      final api = ApiService(AppConstants.serverUrl);
      final now = DateTime.now().toIso8601String();
      await api.postRequest('masters/${user!.master!.id}/availability', {
        'start_time': now,
        'duration': durationMinutes,
      });
      await _refreshOwnAvailabilityFromServer();
      await _softRefreshMasters();
      if (!mounted) return;
      AppToast.show('Ви стали вільним на $durationMinutes хв', background: Colors.green,duration: Duration(seconds: 5));
    } catch (e) {
      if (!mounted) return;
      AppToast.show('Не вдалося встановити доступність', background: Colors.red,duration: Duration(seconds: 5));
    }
  }

  /// Applies zoom-based filtering rules and rebuilds markers/clustering flags.
  void _updateVisibleMasters() {
    if (!_controllerReady()) return;
    if (!mounted) return;

    final zoom = mapController.camera.zoom;

    _isRefreshing = true;

    List<Master> newVisible = List.from(mapMasters);

    // Determine desired selected id: prefer persisted id; otherwise infer from current index
    int? desiredSelectedId = _selectedMasterId;
    // If nothing is selected, keep no selection

    // Compute new index based on desired id; only fall back if that id is missing
    int newIndex;
    if (desiredSelectedId != null) {
      final idx = newVisible.indexWhere((m) => m.id == desiredSelectedId);
      if (idx != -1) {
        newIndex = idx;
      } else {
        // Selected master disappeared — clear selection
        newIndex = -1;
        desiredSelectedId = null;
      }
    } else {
      newIndex = -1;
    }

    // We don't reorder the list anymore; selection is id-based only

    setState(() {
      visibleMasters = newVisible;
      selectedIndex = newIndex;
      _selectedMasterId = desiredSelectedId;
      _currentZoom = zoom;
      _createMarkers();
    });

    _isRefreshing = false;
  }

  bool _controllerReady() {
    try {
      mapController.camera; // access to see if attached
      return true;
    } catch (_) {
      return false;
    }
  }

  String _buildPhotoUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = AppConstants.publicServerUrl.endsWith('/')
        ? AppConstants.publicServerUrl.substring(0, AppConstants.publicServerUrl.length - 1)
        : AppConstants.publicServerUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  Widget _buildMasterFabChild() {
    if (!_isMaster) {
      return Icon(Icons.add_location_alt_outlined, color: Styles().titleColor);
    }
    if (_masterPhoto == null || _masterPhoto!.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Styles().primaryColor, width: 3),
          color: Colors.white,
        ),
        child: const Icon(Icons.person, color: Colors.grey, size: 30),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Styles().primaryColor, width: 3),
      ),
      child: ClipOval(
        child: Image.network(
          _buildPhotoUrl(_masterPhoto!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const Icon(Icons.person, color: Colors.grey, size: 30);
          },
        ),
      ),
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final double size;
  final Color color;
  final bool bounce;
  final bool isActive;

  const _BouncingDot({
    required this.size,
    required this.color,
    required this.bounce,
    required this.isActive,
  });

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    if (widget.bounce) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BouncingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bounce != widget.bounce) {
      if (widget.bounce) {
        _controller.repeat(reverse: true);
      } else {
        _controller.animateTo(0.0, duration: const Duration(milliseconds: 200));
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final double progress = widget.bounce ? Curves.easeInOut.transform(_controller.value) : 0.0;
        final double amplitude = (widget.size * 0.35).clamp(4.0, 12.0);
        final double dy = -amplitude * progress;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: widget.isActive ? 2 : 1),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: (widget.color == Colors.blue ? Colors.blueAccent : Colors.grey)
                            .withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
