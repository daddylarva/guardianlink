import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nicknameController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();

  File? _imageFile;
  String? _photoUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _nicknameController.text = data['nickname'] ?? '';
            _nameController.text = data['name'] ?? '';
            _birthDateController.text = data['birthDate'] ?? '';
            _photoUrl = data['photoUrl'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 로딩 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 사진 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
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

  Future<String?> _uploadImage(File file) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('User ID is null');
        return null;
      }

      print('Starting image upload for user: $uid');
      final ref = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
      
      // 메타데이터 설정
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': uid,
        },
      );

      print('Uploading file: ${file.path}');
      final uploadTask = ref.putFile(file, metadata);
      
      // 업로드 진행 상태 모니터링
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('Upload progress: $progress');
        },
        onError: (error) {
          print('Upload error: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('업로드 중 오류가 발생했습니다: $error')),
          );
        },
      );

      // 업로드 완료 대기
      final snapshot = await uploadTask;
      print('Upload completed successfully');
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      print('Error uploading image: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미지 업로드 중 오류가 발생했습니다: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
      return null;
    }
  }

  Future<void> _saveProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      setState(() => _loading = true);

      String? uploadedUrl = _photoUrl;
      if (_imageFile != null) {
        uploadedUrl = await _uploadImage(_imageFile!);
        if (uploadedUrl == null) {
          setState(() => _loading = false);
          return;
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nickname': _nicknameController.text.trim(),
        'name': _nameController.text.trim(),
        'birthDate': _birthDateController.text.trim(),
        'photoUrl': uploadedUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving profile: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    try {
      // 현재 선택된 날짜가 있으면 그것을 초기값으로 사용
      DateTime initialDate = DateTime.now();
      if (_birthDateController.text.isNotEmpty) {
        try {
          initialDate = DateFormat('yyyy-MM-dd').parse(_birthDateController.text);
        } catch (e) {
          print('Error parsing date: $e');
        }
      }

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        locale: const Locale('ko', 'KR'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6C63FF),
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('날짜 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: _imageFile != null
              ? Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                )
              : _photoUrl != null
                  ? Image.network(
                      _photoUrl!,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person, size: 40, color: Colors.grey[400]);
                      },
                    )
                  : Icon(Icons.person, size: 40, color: Colors.grey[400]),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(child: imageWidget),
            const SizedBox(height: 24),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '닉네임',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름(실명)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _birthDateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: InputDecoration(
                labelText: '생년월일',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('저장하기', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}