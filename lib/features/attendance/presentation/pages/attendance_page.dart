import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/api_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String _selectedFilter = 'Hôm nay';
  final List<String> _filters = ['Hôm nay', 'Hôm qua', 'Tuần này', 'Tháng này'];

  bool _isCheckedIn = false;
  bool _isPageLoading = false;
  bool _isActionLoading = false;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance({bool silent = false}) async {
    if (!silent) {
      setState(() => _isPageLoading = true);
    }
    final data = await ApiService.getMyAttendance();
    setState(() {
      final payload = data['data'];
      if (payload != null && payload['days'] is List) {
        _history = payload['days'];
      } else {
        _history = [];
      }
      
      _isCheckedIn = false;
      if (_history.isNotEmpty) {
        // Find the latest day with events
        for (var i = _history.length - 1; i >= 0; i--) {
          final day = _history[i];
          final events = day['events'];
          if (events is List && events.isNotEmpty) {
            final lastEvent = events.last;
            if (lastEvent['type'] == 'checkin') {
              _isCheckedIn = true;
            }
            break;
          }
        }
      }
      if (!silent) {
        _isPageLoading = false;
      }
    });
  }

  Future<void> _handleCheckInOut() async {
    setState(() => _isActionLoading = true);
    
    // In a real scenario, this would be determined by whether we are checking in or out
    final bool isCheckingIn = !_isCheckedIn;
    
    double? lat;
    double? lon;
    String? address;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dịch vụ vị trí đang tắt');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Bị từ chối quyền vị trí');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Quyền vị trí bị từ chối vĩnh viễn, vui lòng mở Cài đặt');
      }

      Position position = await Geolocator.getCurrentPosition();
      lat = position.latitude;
      lon = position.longitude;

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          address = '${place.street ?? ""}, ${place.subAdministrativeArea ?? ""}, ${place.administrativeArea ?? ""}, ${place.country ?? ""}';
        }
      } catch (geocodingError) {
        debugPrint("Could not get address (geocoding might not be supported on this platform): $geocodingError");
        address = "Không thể lấy địa chỉ (Chưa hỗ trợ trên thiết bị này)";
      }
    } catch (e) {
      debugPrint("Could not get location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể lấy GPS (Có thể do thiết bị hoặc quyền). Sẽ chấm công không kèm GPS.")),
        );
      }
    }
    
    // Attempt to toggle attendance
    final success = await ApiService.toggleAttendance(
      isCheckingIn,
      lat: lat,
      lon: lon,
      address: address,
    );
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckingIn ? "Đã Check In thành công" : "Đã Check Out thành công"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Refresh history silently without page loading overlay
      await _fetchAttendance(silent: true);
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    } else {
      // Refresh anyway to sync state silently
      await _fetchAttendance(silent: true);
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Có lỗi xảy ra hoặc bạn đã thực hiện thao tác này. Đã đồng bộ lại dữ liệu."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1100;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252728)
          : const Color(0xFFF8FAFC),
      body: _isPageLoading && _history.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Check In / Check Out",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCheckInCard()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildHistoryCard()),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCheckInCard(),
                        const SizedBox(height: 24),
                        _buildHistoryCard(),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCheckInCard() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F20) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Chấm công",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Vui lòng bật Location và kết nối mạng công ty để Check-in.",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isActionLoading ? null : _handleCheckInOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4), // Cyan 500
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              elevation: 0,
            ),
            child: _isActionLoading 
              ? const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                )
              : Text(
                  _isCheckedIn ? "Check Out" : "Check In",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F20) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Lịch sử chấm công",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    dropdownColor: isDark ? const Color(0xFF252728) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedFilter = newValue;
                        });
                      }
                    },
                    items: _filters.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _fetchAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4), // Cyan 500
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: const Text("Lọc"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_history.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = _history[index];
                
                // Extract events array
                final events = record['events'] as List?;
                
                // Default to record's date if no recordedAt is found
                String dateStr = record['date']?.toString() ?? "Hôm nay";
                
                // Try to get recordedAt from the first event
                if (events != null && events.isNotEmpty) {
                  final firstEvent = events.first;
                  if (firstEvent['recordedAt'] != null) {
                    dateStr = firstEvent['recordedAt'].toString();
                  }
                }
                
                // Format the date
                String formattedDate = dateStr;
                try {
                  if (dateStr.contains('T')) {
                    // Parse as UTC then convert to local to get correct local date
                    final d = DateTime.parse(dateStr).toLocal();
                    formattedDate = "${d.day}/${d.month}/${d.year}";
                  }
                } catch (_) {}
                
                final totalHours = record['totalHours'] ?? 0;
                final eventsCount = events?.length ?? 0;
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tổng giờ: $totalHours giờ",
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Đã ghi nhận dữ liệu checkin/checkout.",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.blueGrey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "Sự kiện: $eventsCount",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else if (!_isPageLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "Chưa có dữ liệu chấm công",
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
