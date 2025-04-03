import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class ChildLocationScreen extends StatefulWidget {
  final String childId;

  const ChildLocationScreen({super.key, required this.childId});

  @override
  State<ChildLocationScreen> createState() => _ChildLocationScreenState();
}

class _ChildLocationScreenState extends State<ChildLocationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LatLng? _childLocation;
  String? _address;
  String? _landmark;
  bool _isLoading = true;
  String? _error;
  int _updateInterval = 5;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _locationHistory = [];
  String? _profilePhotoUrl;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadChildLocation();
    _loadUpdateInterval();
    _loadProfilePhoto();
    _loadLocationHistory();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.childId).get();
      if (doc.exists) {
        setState(() {
          _nickname = doc.data()?['nickname'] as String?;
        });
      }
    } catch (e) {
      print('닉네임 로드 실패: $e');
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.childId).get();
      if (doc.exists) {
        setState(() {
          _profilePhotoUrl = doc.data()?['photoUrl'] as String?;
        });
      }
    } catch (e) {
      print('프로필 사진 로드 실패: $e');
    }
  }

  Future<void> _loadLocationHistory() async {
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(widget.childId)
          .collection('location_history')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _locationHistory = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print('위치 히스토리 로드 실패: $e');
    }
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadLocationHistory();
    }
  }

  Future<void> _loadUpdateInterval() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.childId)
          .collection('settings')
          .doc('location')
          .get();

      if (doc.exists) {
        setState(() {
          _updateInterval = doc.data()?['updateInterval'] ?? 5;
        });
      }
    } catch (e) {
      print('위치 업데이트 주기 로드 실패: $e');
    }
  }

  Future<void> _saveUpdateInterval(int minutes) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.childId)
          .collection('settings')
          .doc('location')
          .set({
        'updateInterval': minutes,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      setState(() {
        _updateInterval = minutes;
      });
    } catch (e) {
      print('위치 업데이트 주기 저장 실패: $e');
    }
  }

  Future<void> _loadChildLocation() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.childId).get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['lastLocation'] != null) {
          final location = data['lastLocation'] as Map<String, dynamic>;
          final latitude = location['latitude'] as double;
          final longitude = location['longitude'] as double;
          
          setState(() {
            _childLocation = LatLng(latitude, longitude);
            _address = location['address'] as String?;
            _landmark = location['landmark'] as String?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = '위치 정보를 찾을 수 없습니다.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = '자녀 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '위치 정보를 불러오는 중 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromLocation(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = '${place.locality} ${place.thoroughfare}';
        final landmark = place.name;

        setState(() {
          _address = address;
          _landmark = landmark;
        });

        // Firestore에 주소 정보 저장
        await _firestore.collection('users').doc(widget.childId).update({
          'lastLocation.address': address,
          'lastLocation.landmark': landmark,
        });
      }
    } catch (e) {
      print('주소 변환 실패: $e');
    }
  }

  void _showUpdateIntervalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 업데이트 주기 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('자녀의 위치를 몇 분마다 확인하시겠습니까?'),
            const SizedBox(height: 16),
            DropdownButton<int>(
              value: _updateInterval,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1분')),
                DropdownMenuItem(value: 5, child: Text('5분')),
                DropdownMenuItem(value: 10, child: Text('10분')),
                DropdownMenuItem(value: 15, child: Text('15분')),
                DropdownMenuItem(value: 30, child: Text('30분')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _saveUpdateInterval(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nickname != null ? '$_nickname 님의 위치' : '자녀 위치'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showDatePicker,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showUpdateIntervalDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _childLocation == null
                  ? const Center(child: Text('위치 정보가 없습니다.'))
                  : Column(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                          child: FlutterMap(
                            options: MapOptions(
                              center: _childLocation,
                              zoom: 15.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _childLocation!,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        image: _profilePhotoUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage(_profilePhotoUrl!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: _profilePhotoUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 20,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (_locationHistory.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _locationHistory
                                          .map((location) => LatLng(
                                                location['latitude'] as double,
                                                location['longitude'] as double,
                                              ))
                                          .toList(),
                                      color: Colors.blue.withOpacity(0.5),
                                      strokeWidth: 3,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade800,
                                  Colors.purple.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '마지막 위치',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_updateInterval}분마다 업데이트',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_address != null)
                                  Text(
                                    _address!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (_landmark != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '주변: $_landmark',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  '${DateFormat('yyyy년 MM월 dd일').format(_selectedDate)}의 이동 경로',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_locationHistory.isNotEmpty)
                                  Text(
                                    '총 ${_locationHistory.length}개의 위치 기록',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
} 