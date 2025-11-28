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
// FCM removed
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
import 'package:carbeat/widgets/master_details_sheet.dart';
import 'package:carbeat/widgets/master_expandable_sheet.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  MapViewState createState() => MapViewState();
}

class MapViewState extends State<MapView>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
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

  // Periodic refresh removed (replaced by Socket.IO realtime)

  // Debounce for map events
  Timer? _mapEventDebounce;
  static const Duration mapEventDebounceDuration = Duration(milliseconds: 120);

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
  bool _isUpdatingMasterStatus = false;

  // Cached zoom level so we can detect threshold crossings.
  double _currentZoom = 0;

  // Guard to suppress page change handling while we refresh/rebuild lists
  bool _isRefreshing = false;
  bool _softRefreshing = false;
  bool _presentingModal = false;

  // Cache to reuse lightweight marker widgets
  final Map<int, Widget> _lightMarkerCache = {};
  // Notifications tracking
  // Realtime via Socket.IO
  IO.Socket? _socket;
  bool _socketConnected = false;
  bool _centeredOnOwnMaster = false;

  // Masters that should currently be shown on the map after applying zoom-based
  // filtering rules.
  List<Master> visibleMasters = [];

  int? _selectedMasterId;

  bool _locationPermissionGranted = true;
  bool _locationPermanentlyDenied = false;
  bool _locationServicesEnabled = true;
  bool _usingFallbackLocation = false;
  bool _locationInitInProgress = false;
  bool _shouldRecheckLocationOnResume = false;

  late final StreamSubscription _mapSub;
  bool _isRouteVisible = false;
  bool _isRouteSubscribed = false;

  // Threshold: show detailed markers above this zoom, blue dots otherwise
  static const double _markerDetailZoomThreshold = 15.0;
  static const LatLng _fallbackLocation = LatLng(50.4501, 30.5234);

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
    // Try to center on own master shortly after startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnOwnMasterIfNeeded();
    });

    // Listen for map movements/zoom changes to update visible masters.
    _mapSub = MapViewState.mapController.mapEventStream.listen((event) {
      _mapEventDebounce?.cancel();
      _mapEventDebounce = Timer(mapEventDebounceDuration, () {
        if (mounted) _updateVisibleMasters();
      });
    });

    // Connect to Socket.IO for realtime availability updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _socket = IO.io(
          AppConstants.socketBaseUrl,
          IO.OptionBuilder()
              .setTransports(['websocket', 'polling'])
              .setPath('/socket.io/')
              .disableAutoConnect()
              .build(),
        );
        _socket!.on('connect', (_) {
          _socketConnected = true;
        });
        _socket!.on('disconnect', (_) {
          _socketConnected = false;
        });
        _socket!.on('availability:update', (data) {
          if (data is Map) {
            final mapped = data.map((k, v) => MapEntry(k.toString(), v));
            _handleNotification(mapped.cast<String, dynamic>());
          }
        });
        // New masters (created) should appear immediately
        _socket!.on('master:created', (data) async {
          try {
            if (data is Map) {
              final mapped = data.map((k, v) => MapEntry(k.toString(), v));
              final json = mapped.cast<String, dynamic>();
              // Avoid duplicates
              final int? id = int.tryParse(json['id']?.toString() ?? '');
              if (id != null && !mapMasters.any((m) => m.id == id)) {
                final master = Master.fromJson(json);
                setState(() {
                  mapMasters.add(master);
                  _updateVisibleMasters();
                });
              }
            }
          } catch (_) {}
        });
        // Optional: update existing markers on profile changes
        _socket!.on('master:updated', (data) async {
          try {
            if (data is Map) {
              final mapped = data.map((k, v) => MapEntry(k.toString(), v));
              final json = mapped.cast<String, dynamic>();
              final int? id = int.tryParse(json['id']?.toString() ?? '');
              if (id == null) return;
              final updated = Master.fromJson(json);
              bool changed = false;
              for (int i = 0; i < mapMasters.length; i++) {
                if (mapMasters[i].id == id) {
                  mapMasters[i] = updated;
                  changed = true;
                  break;
                }
              }
              if (!changed) {
                mapMasters.add(updated);
              }
              if (mounted) _updateVisibleMasters();
            }
          } catch (_) {}
        });
        _socket!.connect();
      } catch (_) {}
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
      // periodic refresh removed
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_shouldRecheckLocationOnResume) {
        _shouldRecheckLocationOnResume = false;
        _retryLocationRequest(resetData: true);
      }
      if (_isRouteVisible) {
        // periodic refresh removed
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
    // periodic refresh removed
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
    // periodic refresh removed
    // Attempt to center on own master when returning to this route
    _centerOnOwnMasterIfNeeded();
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
    // periodic refresh removed
  }

  @override
  void didPop() {
    _isRouteVisible = false;
    // periodic refresh removed
  }

  Future<void> _retryLocationRequest({bool resetData = false}) async {
    if (!mounted) return;
    if (resetData) {
      setState(() {
        loading = true;
        mapMasters.clear();
        masters.clear();
        currentPage = 1;
        totalPages = 1;
        mapWasLoaded = false;
        _selectedMasterId = null;
        selectedIndex = -1;
      });
    }
    await _initLocationAndLoadData();
  }

  Future<void> _initLocationAndLoadData() async {
    if (_locationInitInProgress) return;
    _locationInitInProgress = true;
    try {
      final hasPermission = await _ensureLocationAccess();

      // Try to get location with timeout only if permission granted
      LatLng? location;
      if (hasPermission) {
      try {
        location = await LocationService.getCurrentLocation().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {
        location = null;
      }
      }

      bool usingFallback = false;
      if (location == null) {
        location = _fallbackLocation;
        usingFallback = true;
      }
      if (!mounted) return;
      final bool wasUsingFallback = _usingFallbackLocation;
      setState(() {
        currentLocation = location;
        _usingFallbackLocation = usingFallback || !hasPermission;
      });
      final bool controllerReady = _controllerReady();
      final bool shouldCenter =
          !_usingFallbackLocation && hasPermission && controllerReady;
      final bool recoveredFromFallback =
          wasUsingFallback && !_usingFallbackLocation && controllerReady;
      if (shouldCenter || recoveredFromFallback) {
        AnimationService.animatedMapMove(
          mapController,
          _animationController,
          location,
          mapController.camera.zoom,
        );
      }
      await _loadMapData(location);

      // Initial filtering once data is loaded.
      _updateVisibleMasters();
      if (mounted) {
        setState(() {
          _locationPermissionGranted = hasPermission;
          loading = false;
        });
      }
    } catch (_) {
      // As last resort, show default map and allow user to proceed
      if (!mounted) return;
      setState(() {
        currentLocation = currentLocation ?? _fallbackLocation;
        loading = false;
        _usingFallbackLocation = true;
      });
      _updateVisibleMasters();
    } finally {
      _locationInitInProgress = false;
    }
  }

  Future<bool> _ensureLocationAccess() async {
    bool servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      if (mounted) {
        setState(() {
          _locationServicesEnabled = false;
          _locationPermissionGranted = false;
          _locationPermanentlyDenied = false;
        });
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    final permanentlyDenied = permission == LocationPermission.deniedForever;

    if (mounted) {
      setState(() {
        _locationServicesEnabled = true;
        _locationPermissionGranted = granted;
        _locationPermanentlyDenied = permanentlyDenied;
      });
    }

    return granted;
  }

  Future<List<Master>> getData(
    double longitude,
    double latitude,
    int page,
    double zoom,
  ) async {
    String serverUrl = AppConstants.serverUrl;
    final String locale = await LanguageService.getLanguage() ?? 'en';
    Map<String, dynamic> params = {
      'lng': longitude,
      'lat': latitude,
      'zoom': zoom,
      'page': page,
      'locale': locale,
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
      AppToast.show(
        'Сервер тимчасово недоступний. Спробуйте пізніше.',
        background: Colors.red,
        duration: Duration(seconds: 10),
      );
      return [];
    } catch (_) {
      if (!mounted) return [];
      setState(() {
        loading = false;
      });
      AppToast.show(
        'Виникла помилка під час завантаження.',
        background: Colors.red,
        duration: Duration(seconds: 10),
      );
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
    // After initial data load, center on own master if applicable
    _centerOnOwnMasterIfNeeded();
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
    final List<GarageMarker> availableMarkers = [];
    final List<GarageMarker> unavailableMarkers = [];
    GarageMarker? selectedMarker;
    for (int i = 0; i < visibleMasters.length; i++) {
      final master = visibleMasters[i];
      if (seenMasterIds.contains(master.id)) continue;
      seenMasterIds.add(master.id);
      final bool isActive = i == selectedIndex;
      final double markerSize = isActive ? 52.0 : 40.0;

      final Widget child = Stack(
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
          PulsatingMaster(master: master, isActive: isActive),
        ],
      );

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
          child: child,
        ),
      );

      if (isActive) {
        selectedMarker = marker;
      } else if (master.available) {
        availableMarkers.add(marker);
      } else {
        unavailableMarkers.add(marker);
      }
    }
    // Draw order: unavailable first, then available, then selected on very top
    masters.addAll(unavailableMarkers);
    masters.addAll(availableMarkers);
    if (selectedMarker != null) masters.add(selectedMarker!);
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

    // Prefetch full master data
    final int masterId = visibleMasters[index].id;
    ApiService(AppConstants.serverUrl).getRequest('masters/$masterId');
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
    if (_usingFallbackLocation) {
      AppToast.show(
        'Надайте доступ до геолокації, щоб перейти до вашої позиції.',
        background: Colors.orange,
      );
      return;
    }
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
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Styles().primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final mastersToShow = List<Master>.from(visibleMasters);
        // Compute distance (km) from current location and sort: available first, then by distance asc
        final Distance distanceCalc = Distance();
        final bool canMeasureDistance =
            currentLocation != null && !_usingFallbackLocation;
        final List<Map<String, dynamic>> items =
            mastersToShow.map((m) {
              final double km =
                  (canMeasureDistance)
                      ? distanceCalc.as(
                        LengthUnit.Kilometer,
                        currentLocation!,
                        m.location,
                      )
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Masters (${items.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Styles().titleColor,
                        ),
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
                          foregroundImage:
                              (m.mainPhoto.isNotEmpty)
                                  ? NetworkImage(_buildPhotoUrl(m.mainPhoto))
                                  : null,
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                        title: Text(
                          m.name,
                          style: TextStyle(color: Styles().titleColor),
                        ),
                        subtitle: Row(
                          children: [
                            if (m.available)
                              Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.circle,
                                  color: Styles().checkColor,
                                  size: 10,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                '~${km.isFinite ? km.toStringAsFixed(2) : '--'} km',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Styles().backgroundFormColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${m.rating.toStringAsFixed(1)}★'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          final idx = visibleMasters.indexWhere(
                            (vm) => vm.id == m.id,
                          );
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
      useRootNavigator: true,
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

  Future<void> _openSystemLocationSettings() async {
    _shouldRecheckLocationOnResume = true;
    try {
      final opened = await Geolocator.openLocationSettings();
      if (!opened) {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Widget _buildLocationPermissionBanner(BuildContext context) {
    if (_locationPermissionGranted && _locationServicesEnabled) {
      return const SizedBox.shrink();
    }

    final bool servicesDisabled = !_locationServicesEnabled;
    final theme = Theme.of(context);
    final String title = servicesDisabled
        ? 'Геолокація вимкнена'
        : _locationPermanentlyDenied
            ? 'Надайте доступ до геолокації'
            : 'Дозвольте доступ до геолокації';
    final String subtitle = servicesDisabled
        ? 'Увімкніть служби геолокації, щоб показати майстрів поруч.'
        : 'Ми не можемо показати ваше місцезнаходження без дозволу.';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.85),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!servicesDisabled && !_locationPermanentlyDenied)
                    TextButton(
                      onPressed: () => _retryLocationRequest(resetData: true),
                      child: const Text(
                        'Надати доступ',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _openSystemLocationSettings,
                    child: Text(
                      'Налаштування',
                      style: TextStyle(color: Styles().checkColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const Center(child: Loading());
    }
    return Scaffold(
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
                userAgentPackageName: 'online.carbeat',
                tileProvider: const FMTCStore('mapStore').getTileProvider(),
              ),
              // User location marker
              if (currentLocation != null && !_usingFallbackLocation)
                UserLocationMarker(location: currentLocation!),
              // Маркери: кластеризація якщо в межах екрана > 100
              if (_countMastersInViewport() > 100)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: const Size(40, 40),
                    markers: masters,
                    showPolygon: false,
                    builder: (context, clusterMarkers) {
                      final gm =
                          clusterMarkers.whereType<GarageMarker>().toList();
                      return ClusterCircle(markers: gm);
                    },
                  ),
                )
              else
                MarkerLayer(markers: masters),
            ],
          ),
          // Positioned(
          //   right: 10,
          //   top: MediaQuery.of(context).size.height * 0.15,
          //   child: FloatingActionButton(
          //     heroTag: 'master_fab',
          //     onPressed: () async {
          //       if (_isUpdatingMasterStatus) return;

          //       if (_isMaster) {
          //         await showModalBottomSheet(
          //           context: context,
          //           useRootNavigator: true,
          //           isScrollControlled: true,
          //           backgroundColor: Colors.transparent,
          //           builder: (_) => const MasterProfileSheet(),
          //         ).then((_) {
          //           if (mounted) {
          //             _updateMasterStatus();
          //           }
          //         });
          //       } else {
          //         if (!mounted) return;
          //         await showMasterDialog(
          //           context,
          //           onAuthorized: () async {
          //             if (mounted) {
          //               await _updateMasterStatus();
          //             }
          //           },
          //           onStartRegistration: (phone) async {
          //             if (!mounted) return;
          //             await showModalBottomSheet(
          //               context: context,
          //               useRootNavigator: true,
          //               isScrollControlled: true,
          //               backgroundColor: Colors.transparent,
          //               builder: (_) => MasterRegistrationFlowSheet(
          //                 phone: phone,
          //                 parentContext: context,
          //               ),
          //             ).then((_) async {
          //               if (mounted) {
          //                 await _updateMasterStatus();
          //               }
          //             });
          //           },
          //         );
          //       }
          //     },
          //     backgroundColor: Styles().primaryColor,
          //     elevation: 10.0,
          //     child: !_isMaster
          //       ? Icon(Icons.add_location_alt_outlined, color: Styles().titleColor)
          //       : _masterPhoto != null && _masterPhoto!.isNotEmpty
          //         ? CircleAvatar(
          //             backgroundColor: Colors.white,
          //             backgroundImage: NetworkImage(_buildPhotoUrl(_masterPhoto!)),
          //             onBackgroundImageError: (_, __) {},
          //             child: null,
          //           )
          //         : CircleAvatar(
          //             backgroundColor: Colors.white,
          //             child: Icon(Icons.person, color: Colors.grey),
          //           ),
          //   ),
          // ),
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
            right: 10,
            top: MediaQuery.of(context).size.height * 0.05,
            child: Builder(
              builder: (context) {
                final serviceProvider = Provider.of<ServiceProvider>(context);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FloatingActionButton(
                        heroTag: 'master_fab',
                        onPressed: () async {
                          if (_isMaster) {
                            await showModalBottomSheet(
                              context: context,
                              useRootNavigator: true,
                              isScrollControlled: true,
                              backgroundColor: Styles().primaryColor,
                              builder: (_) => const MasterProfileSheet(),
                            ).then((_) async {
                              // Refresh auth-dependent UI after closing the sheet (e.g., after logout)
                              await _updateMasterStatus();
                              if (mounted) {
                                setState(() {
                                  // also clear selection to avoid showing master-only UI states
                                  _selectedMasterId = null;
                                  selectedIndex = -1;
                                  _createMarkers();
                                });
                              }
                            });
                          } else {
                            await showMasterDialog(
                              context,
                              onAuthorized: _updateMasterStatus,
                              onStartRegistration: (phone) {
                                showModalBottomSheet(
                                  context: context,
                                  useRootNavigator: true,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (_) => MasterRegistrationFlowSheet(
                                        phone: phone,
                                        parentContext: context,
                                      ),
                                ).then((_) => _updateMasterStatus());
                              },
                            );
                          }
                        },
                        backgroundColor: Styles().primaryColor,
                        elevation: 10.0,
                        child:
                            !_isMaster
                                ? Icon(
                                  Icons.add_location_alt_outlined,
                                  color: Styles().titleColor,
                                )
                                : Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Styles().primaryColor,
                                  ),
                                  child:
                                      _masterPhoto != null &&
                                              _masterPhoto!.isNotEmpty
                                          ? ClipOval(
                                            child: Image.network(
                                              _buildPhotoUrl(_masterPhoto!),
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => const Icon(
                                                    Icons.person,
                                                    color: Colors.blueGrey,
                                                    size: 30,
                                                  ),
                                            ),
                                          )
                                          : const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.extended(
                        heroTag: 'service_filter_fab',
                        onPressed: () {},
                        backgroundColor: Styles().primaryColor,
                        elevation: 10.0,
                        label: SizedBox(
                          width: 200,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DropdownItem>(
                              isExpanded: true,
                              value: selectedService,
                              hint: Text(
                                'Послуга',
                                style: TextStyle(color: Styles().titleColor),
                              ),
                              iconEnabledColor: Styles().titleColor,
                              dropdownColor: Styles().primaryColor,
                              items: [
                                DropdownMenuItem<DropdownItem>(
                                  value: null,
                                  child: Text(
                                    'Всі послуги',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Styles().titleColor,
                                    ),
                                  ),
                                ),
                                ...serviceProvider.services.map(
                                  (s) => DropdownMenuItem<DropdownItem>(
                                    value: DropdownItem(id: s.id, name: s.name),
                                    child: Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Styles().titleColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (DropdownItem? item) async {
                                setState(() {
                                  selectedService = item;
                                  filterServiceId = item?.id;
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
                            ),
                          ),
                        ),
                      ),
                      if (_isMaster) ...[
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          heroTag: 'availability_fab',
                          onPressed: _toggleAvailability,
                          backgroundColor: Styles().primaryColor,
                          elevation: 10.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isAvailable ? Styles().checkColor : Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _isAvailable ? Icons.toggle_on : Icons.toggle_off,
                              color: _isAvailable ? Styles().titleColor : Styles().primaryColor,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Extra button allowing masters to toggle their availability.
          // if (_isMaster)
          // Positioned(
          //     right: 10,
          //     top: MediaQuery.of(context).size.height * 0.15,
          //     child: FloatingActionButton(
          //       heroTag: 'availability_fab',
          //       onPressed: _toggleAvailability,
          //       backgroundColor: Styles().primaryColor,
          //       elevation: 10.0,
          //       child: Icon(
          //         _isAvailable ? Icons.toggle_on : Icons.toggle_off,
          //         color: _isAvailable ? Colors.greenAccent : Colors.grey,
          //         size: 28,
          //       ),
          //     ),
          //   ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    )
                    .chain(CurveTween(curve: Curves.easeOutCubic))
                    .animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child:
                  (_selectedMasterId != null &&
                          visibleMasters.any((m) => m.id == _selectedMasterId))
                      ? Builder(builder: (context) {
                          final idx = visibleMasters.indexWhere((m) => m.id == _selectedMasterId);
                          if (idx == -1) return const SizedBox.shrink();
                          final master = visibleMasters[idx];
                          return MasterExpandableSheet(key: ValueKey('expand_${master.id}'), master: master);
                        })
                       : const SizedBox.shrink(),
            ),
          ),
          if (loading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(child: Loading()),
              ),
            ),
          _buildLocationPermissionBanner(context),
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
    try {
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _startRefreshTimer() {}
  void _stopRefreshTimer() {}

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
        futures.add(
          getData(
            currentLocation!.longitude,
            currentLocation!.latitude,
            page,
            mapController.camera.zoom,
          ),
        );
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
    if (_isUpdatingMasterStatus) return;
    try {
      _isUpdatingMasterStatus = true;
      final bool wasMaster = _isMaster;
      final user = await UserService().getUser();
      if (!mounted) return;
      setState(() {
        _isMaster = user?.master != null;
        _masterPhoto = user?.master?.mainPhoto;
      });
      // If the user has just become a master, refresh markers and center on their marker
      if (_isMaster && !wasMaster) {
        await _softRefreshMasters();
        _centerOnOwnMasterIfNeeded();
      }
      await _refreshOwnAvailabilityFromServer();
    } finally {
      _isUpdatingMasterStatus = false;
    }
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
      final res = await api.getRequest(
        'masters/${user!.master!.id}/availability',
      );
      bool serverAvailable = false;
      if (res is Map) {
        if (res.containsKey('available')) {
          final val = res['available'];
          if (val is bool) {
            serverAvailable = val;
          } else if (val is num)
            serverAvailable = val != 0;
          else if (val is String)
            serverAvailable = val == '1' || val.toLowerCase() == 'true';
        } else if (res.containsKey('availability')) {
          final val = res['availability'];
          if (val is bool) {
            serverAvailable = val;
          } else if (val is num)
            serverAvailable = val != 0;
          else if (val is String)
            serverAvailable = val == '1' || val.toLowerCase() == 'true';
        } else if (res.containsKey('data')) {
          final data = res['data'];
          if (data is Map) {
            if (data.containsKey('available')) {
              final val = data['available'];
              if (val is bool) {
                serverAvailable = val;
              } else if (val is num)
                serverAvailable = val != 0;
              else if (val is String)
                serverAvailable = val == '1' || val.toLowerCase() == 'true';
            } else if (data.containsKey('availability')) {
              final val = data['availability'];
              if (val is bool) {
                serverAvailable = val;
              } else if (val is num)
                serverAvailable = val != 0;
              else if (val is String)
                serverAvailable = val == '1' || val.toLowerCase() == 'true';
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
        // Optimistic: go busy immediately
        final bool prev = _isAvailable;
        setState(() => _isAvailable = false);
        await _applyOwnAvailabilityLocally(false);
        try {
          await api.deleteRequest('masters/${user!.master!.id}/availability');
          // Optional: soft refresh in background
          _refreshOwnAvailabilityFromServer();
          _softRefreshMasters();
        } catch (_) {
          // Revert on failure
          if (mounted) setState(() => _isAvailable = prev);
          await _applyOwnAvailabilityLocally(prev);
          if (mounted) {
            AppToast.show(
              'Не вдалося змінити статус',
              background: Colors.red,
              duration: Duration(seconds: 5),
            );
          }
        }
      } else {
        _showAvailabilitySheet();
      }
    } catch (_) {}
  }

  void _showAvailabilitySheet() {
    int minutes = 60;
    final TextEditingController ctrl = TextEditingController(
      text: minutes.toString(),
    );
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
                'Стати вільним на:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Styles().titleColor,
                ),
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
                        fillColor: Styles().backgroundFormColor,
                        hintText: 'Хвилин',
                        hintStyle: TextStyle(
                          color: Styles().primaryColor.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: Icon(
                          Icons.timer_outlined,
                          color: Styles().primaryColor,
                        ),
                      ),
                      style: TextStyle(
                        color: Styles().primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: Styles().titleColor,
                      onChanged: (val) {
                        final n = int.tryParse(val);
                        if (n != null && n > 0) minutes = n;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        label: Text(
                          '30 хв',
                          style: TextStyle(color: Styles().titleColor),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles().checkColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          minutes += 30;
                          ctrl.text = minutes.toString();
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                        label: Text(
                          '30 хв',
                          style: TextStyle(color: Styles().titleColor),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles().checkColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          minutes = (minutes - 30).clamp(30, 24 * 60);
                          ctrl.text = minutes.toString();
                        },
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
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Styles().primaryColor, width: 1.5),
                        foregroundColor: Styles().titleColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Скасувати',
                        style: TextStyle(color: Styles().titleColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.timer, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles().checkColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final n = int.tryParse(ctrl.text) ?? minutes;
                        final duration = n > 0 ? n : 60;
                        Navigator.pop(ctx);
                        await _setAvailability(duration);
                      },
                      label: Text(
                        'Стати вільним',
                        style: TextStyle(color: Styles().titleColor),
                      ),
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
    // Optimistic: become available immediately
    final bool prev = _isAvailable;
    setState(() => _isAvailable = true);
    await _applyOwnAvailabilityLocally(true);
    if (mounted) {
      AppToast.show(
        'Ви стали вільним на $durationMinutes хв',
        background: Colors.green,
        duration: Duration(seconds: 5),
      );
    }
    try {
      final api = ApiService(AppConstants.serverUrl);
      // Let server use its own current time to avoid timezone skew issues
      await api.postRequest('masters/${user!.master!.id}/availability', {
        'duration': durationMinutes,
      });
      // Background reconcile
      _refreshOwnAvailabilityFromServer();
      _softRefreshMasters();
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => _isAvailable = prev);
      await _applyOwnAvailabilityLocally(prev);
      if (mounted) {
        AppToast.show(
          'Не вдалося встановити доступність',
          background: Colors.red,
          duration: Duration(seconds: 5),
        );
      }
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
    final base =
        AppConstants.publicServerUrl.endsWith('/')
            ? AppConstants.publicServerUrl.substring(
              0,
              AppConstants.publicServerUrl.length - 1,
            )
            : AppConstants.publicServerUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  Future<void> _centerOnOwnMasterIfNeeded() async {
    if (_centeredOnOwnMaster) return;
    try {
      final user = await UserService().getUser();
      final myMaster = user?.master;
      if (myMaster == null) return;
      final target = myMaster.location;
      if (_controllerReady()) {
        AnimationService.animatedMapMove(
          mapController,
          _animationController,
          target,
          17,
        );
        // Select marker if present
        final idx = visibleMasters.indexWhere((m) => m.id == myMaster.id);
        if (idx != -1 && mounted) {
          setState(() {
            selectedIndex = idx;
            _selectedMasterId = myMaster.id;
            _createMarkers();
          });
        }
        _centeredOnOwnMaster = true;
      }
    } catch (_) {}
  }

  Widget _buildMasterFabChild() {
    if (!_isMaster) {
      return Icon(Icons.add_location_alt_outlined, color: Styles().titleColor);
    }

    if (_masterPhoto != null && _masterPhoto!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _buildPhotoUrl(_masterPhoto!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  const Icon(Icons.person, color: Colors.grey, size: 30),
        ),
      );
    }

    return const Icon(Icons.person, color: Colors.grey, size: 30);
  }

  void _showMasterSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Styles().primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _isMaster ? 'Профіль майстра' : 'Стати майстром',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Styles().titleColor,
                        ),
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
                  child:
                      _isMaster
                          ? const MasterProfileSheet()
                          : MasterRegistrationFlowSheet(
                            phone: '',
                            parentContext: context,
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleNotification(Map<String, dynamic> data) async {
    try {
      final type = (data['type'] ?? data['event'] ?? '').toString().toLowerCase();
      // Accept events without a type if they contain availability payload
      if (type.isNotEmpty && !type.contains('avail')) return;
      final dynamic idRaw = data['master_id'] ?? data['id'] ?? data['master'];
      if (idRaw == null) return;
      final int? masterId = int.tryParse(idRaw.toString());
      if (masterId == null) return;
      final dynamic availRaw = data['available'] ?? data['status'] ?? data['is_available'];
      bool? available;
      if (availRaw is bool) {
        available = availRaw;
      } else if (availRaw is num) {
        available = availRaw != 0;
      } else if (availRaw is String) {
        available = availRaw == '1' || availRaw.toLowerCase() == 'true';
      }
      if (available == null) return;

      bool changed = false;
      for (int i = 0; i < mapMasters.length; i++) {
        if (mapMasters[i].id == masterId && mapMasters[i].available != available) {
          mapMasters[i].available = available;
          changed = true;
          break;
        }
      }
      // If this is my master – mirror the toggle button state
      try {
        final user = await UserService().getUser();
        final int? myMasterId = user?.master?.id;
        if (myMasterId != null && myMasterId == masterId) {
          if (_isAvailable != available) {
            if (mounted) setState(() => _isAvailable = available!);
          }
        }
      } catch (_) {}

      if (changed) {
        _lightMarkerCache.remove(masterId * 10 + 1);
        _lightMarkerCache.remove(masterId * 10 + 0);
        _updateVisibleMasters();
      }
    } catch (_) {}
  }

  Future<void> _applyOwnAvailabilityLocally(bool available) async {
    final user = await UserService().getUser();
    if (user?.master == null) return;
    final int myId = user!.master!.id;
    bool changed = false;
    for (int i = 0; i < mapMasters.length; i++) {
      if (mapMasters[i].id == myId && mapMasters[i].available != available) {
        mapMasters[i].available = available;
        changed = true;
        break;
      }
    }
    if (changed && mounted) {
      _updateVisibleMasters();
    }
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

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
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
        final double progress =
            widget.bounce ? Curves.easeInOut.transform(_controller.value) : 0.0;
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
              border: Border.all(
                color: Colors.white,
                width: widget.isActive ? 2 : 1,
              ),
              boxShadow:
                  widget.isActive
                      ? [
                        BoxShadow(
                          color: (widget.color == Colors.blue
                                  ? Colors.blueAccent
                                  : Colors.grey)
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
