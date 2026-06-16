import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _labelCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _urlCtrl.dispose(); _labelCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiClientProvider).getJson('/progress/photos');
      if (mounted) setState(() {
        _photos = (d['photos'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _upload() async {
    final url = _urlCtrl.text.trim();
    final label = _labelCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await ref.read(apiClientProvider).postJson('/progress/photos', {
        'photo_url': url,
        'label': label.isEmpty ? 'Progress photo' : label,
      });
      if (mounted) {
        _urlCtrl.clear();
        _labelCtrl.clear();
        Navigator.of(context).pop();
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.coral));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add progress photo', style: T.title(context)),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Photo URL',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. Week 4 front',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _uploading ? null : _upload,
              child: _uploading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save photo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]),
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
              child: Row(children: [
                NeuTopBar(title: 'Progress Photos', onBack: () => context.pop()),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddDialog,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Symbols.add_rounded, color: Colors.white),
                  ),
                ),
              ]),
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
                        final week = p['week'] as int? ?? i + 1;
                        final label = p['label'] as String? ?? 'Week $week';
                        final url = p['photo_url'] as String? ?? '';
                        final date = p['taken_at'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: NeuCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                NeuPill(
                                  color: AppColors.coralSoft,
                                  child: Text('Week $week',
                                    style: const TextStyle(
                                      color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 12)),
                                ),
                                const Spacer(),
                                if (date.isNotEmpty)
                                  Text(date.substring(0, 10), style: T.small(context)),
                              ]),
                              const SizedBox(height: 10),
                              if (url.isNotEmpty)
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
                              const SizedBox(height: 10),
                              Text(label, style: T.title(context).copyWith(fontSize: 14)),
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
