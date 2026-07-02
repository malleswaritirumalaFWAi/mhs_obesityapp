import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_misc.dart';

class ProgressPhotosScreen extends ConsumerStatefulWidget {
  const ProgressPhotosScreen({super.key});
  @override
  ConsumerState<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends ConsumerState<ProgressPhotosScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  final _urlCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _urlCtrl.dispose(); _commentCtrl.dispose(); super.dispose(); }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $ampm';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/progress/photos');
      if (mounted) setState(() {
        _photos = (d['photos'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _uploadUrl(void Function(void Function()) setSheet) async {
    final url = _urlCtrl.text.trim();
    final comment = _commentCtrl.text.trim();
    if (url.isEmpty) return;
    setSheet(() => _uploading = true);
    try {
      await ref.read(apiClientProvider).postJson('/progress/photos', {
        'photo_url': url,
        'comment': comment.isEmpty ? null : comment,
      });
      if (mounted) {
        _urlCtrl.clear();
        _commentCtrl.clear();
        Navigator.of(context).pop();
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.coral));
    } finally {
      setSheet(() => _uploading = false);
    }
  }

  Future<void> _pickAndUpload(ImageSource source, String comment) async {
    Navigator.of(context).pop(); // close the sheet first
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (file == null || !mounted) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final mime = file.mimeType ?? 'image/jpeg';
      await ref.read(apiClientProvider).postJson('/progress/photos/upload', {
        'image_base64': base64Data,
        'mime': mime,
        'comment': comment.isEmpty ? null : comment,
      });
      if (mounted) {
        _commentCtrl.clear();
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.coral));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showAddDialog() {
    _uploading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add progress photo', style: T.title(context)),
            const SizedBox(height: 16),
            // ── Comment field (shared between camera/gallery/URL paths) ──
            TextField(
              controller: _commentCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                hintText: 'e.g. Feeling stronger this week!',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // ── Native picker buttons ──
            Row(children: [
              Expanded(
                child: _PickerButton(
                  icon: Symbols.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => _pickAndUpload(ImageSource.camera, _commentCtrl.text.trim()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerButton(
                  icon: Symbols.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => _pickAndUpload(ImageSource.gallery, _commentCtrl.text.trim()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider(color: AppColors.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or paste URL', style: T.small(context)),
              ),
              const Expanded(child: Divider(color: AppColors.line)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Photo URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _uploading ? AppColors.line : AppColors.coral,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _uploading ? null : () => _uploadUrl(setSheet),
                child: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save photo',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ]),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: NeuCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Symbols.arrow_back_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progress Photos',
                            style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Visualize your transformation',
                            style: TextStyle(
                                color: AppColors.inkSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showAddDialog,
                    child: const Icon(Symbols.add_rounded,
                        color: AppColors.inkMid, size: 22),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Symbols.photo_camera_rounded, size: 56, color: AppColors.inkSoft),
                        const SizedBox(height: 16),
                        Text('No photos yet', style: T.body(context)),
                        const SizedBox(height: 8),
                        Text('Tap + to add your first progress photo',
                          style: T.small(context), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _showAddDialog,
                          child: NeuCard(
                            color: AppColors.coralSoft,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            child: Text('Add photo',
                              style: T.title(context).copyWith(color: AppColors.coral)),
                          ),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: _photos.length,
                      itemBuilder: (_, i) {
                        final p = _photos[i];
                        final url = p['photo_url'] as String? ?? '';
                        final comment = p['comment'] as String? ?? '';
                        final createdAt = p['created_at'] as String? ?? '';
                        final dateLabel = _formatDate(createdAt);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: NeuCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Symbols.photo_camera_rounded,
                                    color: AppColors.coral, size: 16),
                                const SizedBox(width: 6),
                                Text('Photo ${_photos.length - i}',
                                  style: const TextStyle(
                                    color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 13)),
                                const Spacer(),
                                if (dateLabel.isNotEmpty)
                                  Text(dateLabel, style: T.small(context)),
                              ]),
                              const SizedBox(height: 10),
                              if (url.isNotEmpty && url.startsWith('http'))
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    url,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: AppColors.bg,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Icon(Symbols.broken_image_rounded,
                                          color: AppColors.inkSoft, size: 40)),
                                    ),
                                  ),
                                )
                              else if (url.startsWith('data:image'))
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    base64Decode(url.split(',').last),
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: AppColors.bg,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Icon(Symbols.broken_image_rounded,
                                          color: AppColors.inkSoft, size: 40)),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Icon(Symbols.photo_rounded,
                                      color: AppColors.inkSoft, size: 40)),
                                ),
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(comment, style: T.body(context).copyWith(fontSize: 13)),
                              ],
                            ]),
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
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.coral, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.inkMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}
