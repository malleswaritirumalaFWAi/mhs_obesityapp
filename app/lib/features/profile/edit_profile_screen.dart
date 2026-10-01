import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _startWeightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();

  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _loading = true;
  String? _photoUrl;
  String _initial = '?';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _heightCtrl.dispose();
    _startWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getJson('/profile');
      final user = (data['user'] as Map?) ?? {};
      if (!mounted) return;
      setState(() {
        final name = (user['name'] as String?) ?? '';
        _nameCtrl.text = name;
        _emailCtrl.text = (user['email'] as String?) ?? '';
        final h = double.tryParse(user['height']?.toString() ?? '');
        if (h != null) _heightCtrl.text = h.toStringAsFixed(1);
        final sw = double.tryParse(user['start_weight']?.toString() ?? '');
        if (sw != null) _startWeightCtrl.text = sw.toStringAsFixed(1);
        final tw = double.tryParse(user['target_weight']?.toString() ?? '');
        if (tw != null) _targetWeightCtrl.text = tw.toStringAsFixed(1);
        _photoUrl = user['profile_photo_url'] as String?;
        _initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        _loading = false;
      });
    } catch (e) {
      debugPrint('EditProfile: loadProfile failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 50,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final api = ref.read(apiClientProvider);
      // Use raw dio with extended timeouts for large payload
      final response = await api.dio.post(
        '/profile/photo',
        data: {'photo': base64Photo},
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final res = Map<String, dynamic>.from((response.data as Map?) ?? {});
      if (res['updated'] == true) {
        setState(() => _photoUrl = base64Photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed. Please check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      final name = _nameCtrl.text.trim();
      body['name'] = name;
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty) body['email'] = email;
      final h = double.tryParse(_heightCtrl.text.trim());
      if (h != null) body['height'] = h;
      final sw = double.tryParse(_startWeightCtrl.text.trim());
      if (sw != null) body['start_weight'] = sw;
      final tw = double.tryParse(_targetWeightCtrl.text.trim());
      if (tw != null) body['target_weight'] = tw;

      await api.postJson('/profile/update', body);
      ref.invalidate(userProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final status = e.response?.statusCode;
        final url = e.requestOptions.uri;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed (HTTP $status): $url')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit Profile', style: T.title(context)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                children: [
                  // ── Profile photo ──
                  Center(
                    child: GestureDetector(
                      onTap: _uploadingPhoto ? null : _pickPhoto,
                      child: Stack(
                        children: [
                          _buildAvatar(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.coral,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.bg, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: _uploadingPhoto
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Symbols.photo_camera_rounded,
                                      size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Personal info ──
                  NeuCard(
                    depth: 0.5,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PERSONAL INFO', style: T.section(context)),
                        const SizedBox(height: 16),
                        _buildField('Name', _nameCtrl, Symbols.person_rounded),
                        const SizedBox(height: 14),
                        _buildField('Email', _emailCtrl, Symbols.mail_rounded,
                            keyboardType: TextInputType.emailAddress),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Body metrics ──
                  NeuCard(
                    depth: 0.5,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BODY METRICS', style: T.section(context)),
                        const SizedBox(height: 16),
                        _buildField('Height (cm)', _heightCtrl, Symbols.height_rounded,
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 14),
                        _buildField('Start Weight (kg)', _startWeightCtrl,
                            Symbols.monitor_weight_rounded,
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 14),
                        _buildField('Target Weight (kg)', _targetWeightCtrl,
                            Symbols.flag_rounded,
                            keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Save button ──
                  NeuButton.primary(
                    'Save Changes',
                    onPressed: _saving ? null : _save,
                    loading: _saving,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = _photoUrl;
    final hasBase64 = photoUrl != null && photoUrl.startsWith('data:image');

    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.coralSoft,
      backgroundImage: hasBase64
          ? MemoryImage(base64Decode(photoUrl.split(',').last))
          : null,
      child: hasBase64
          ? null
          : Text(_initial,
              style: const TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w800,
                  fontSize: 32)),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.coral.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.coral),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: T.title(context).copyWith(fontSize: 14),
            decoration: InputDecoration(
              labelText: label,
              labelStyle:
                  T.small(context).copyWith(fontSize: 12, color: AppColors.inkSoft),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.line.withValues(alpha: 0.5)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.line.withValues(alpha: 0.5)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.coral),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
