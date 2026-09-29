import 'dart:convert';

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
  String? _photoUrl;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _heightCtrl.dispose();
    _startWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  void _initFromUser(UserProfile user) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = user.name == 'User' ? '' : user.name;
    _emailCtrl.text = user.email;
    if (user.height != null) _heightCtrl.text = user.height!.toStringAsFixed(1);
    if (user.startWeight != null) {
      _startWeightCtrl.text = user.startWeight!.toStringAsFixed(1);
    }
    if (user.targetWeight != null) {
      _targetWeightCtrl.text = user.targetWeight!.toStringAsFixed(1);
    }
    _photoUrl = user.profilePhotoUrl;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final api = ref.read(apiClientProvider);
      final res = await api.postJson('/profile/photo', {'photo': base64Photo});
      if (res['updated'] == true) {
        setState(() => _photoUrl = res['photo_url'] as String?);
        ref.invalidate(userProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
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
      if (name.isNotEmpty) body['name'] = name;
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty) body['email'] = email;
      final h = double.tryParse(_heightCtrl.text.trim());
      if (h != null) body['height'] = h;
      final sw = double.tryParse(_startWeightCtrl.text.trim());
      if (sw != null) body['start_weight'] = sw;
      final tw = double.tryParse(_targetWeightCtrl.text.trim());
      if (tw != null) body['target_weight'] = tw;

      if (body.isEmpty) {
        if (mounted) context.pop();
        return;
      }

      await api.postJson('/profile/update', body);
      ref.invalidate(userProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
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
    final userAsync = ref.watch(userProvider);

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
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) {
          // Still allow editing with empty fields if profile fetch fails
          final fallback = UserProfile(
            name: '', phone: '', email: '', xp: 0, totalXp: 0, streak: 0, badges: [],
          );
          _initFromUser(fallback);
          return _buildForm(fallback);
        },
        data: (user) {
          _initFromUser(user);
          return _buildForm(user);
        },
      ),
    );
  }

  Widget _buildForm(UserProfile user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          // ── Profile photo ──
          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _pickPhoto,
              child: Stack(
                children: [
                  _buildAvatar(user),
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
    );
  }

  Widget _buildAvatar(UserProfile user) {
    final initial = user.initial;
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
          : Text(initial,
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
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8),
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
