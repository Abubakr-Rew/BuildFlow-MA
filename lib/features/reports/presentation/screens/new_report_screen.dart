import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

const _maxPhotos = 5;

/// New report screen — select project, add text + photos, submit.
class NewReportScreen extends ConsumerStatefulWidget {
  const NewReportScreen({super.key});

  @override
  ConsumerState<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends ConsumerState<NewReportScreen> {
  final _textController = TextEditingController();
  String? _selectedProjectId;
  final List<String> _photoPaths = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedProjectId == null) {
      _showSnackBar(AppLocalizations.of(context).selectProjectHint);
      return;
    }
    if (_textController.text.trim().isEmpty) {
      _showSnackBar(AppLocalizations.of(context).reportTextHint);
      return;
    }

    setState(() => _isSubmitting = true);

    // Add fake photo paths if none selected (for demo purposes)
    final photos = _photoPaths.isEmpty
        ? ['fake:demo-${DateTime.now().millisecondsSinceEpoch}']
        : _photoPaths;

    final success = await ref.read(reportsProvider.notifier).submitReport(
          projectId: _selectedProjectId!,
          text: _textController.text.trim(),
          photoPaths: photos,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _showSnackBar(AppLocalizations.of(context).reportSent);
      _textController.clear();
      setState(() {
        _selectedProjectId = null;
        _photoPaths.clear();
      });
    } else {
      _showSnackBar(AppLocalizations.of(context).reportError);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.fromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _photoPaths.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Не удалось выбрать фото: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newReport)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Project selector
            Text(l10n.selectProject, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacing8),
            projects.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString()),
              data: (list) {
                final activeProjects =
                    list.where((p) => p.status.isActive).toList();
                return _ProjectSelector(
                  projects: activeProjects,
                  selectedId: _selectedProjectId,
                  onSelected: (id) =>
                      setState(() => _selectedProjectId = id),
                );
              },
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Report text
            BfTextField(
              label: l10n.reportText,
              hint: l10n.reportTextHint,
              controller: _textController,
              maxLines: 5,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Photo section
            Text(l10n.photos, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacing8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._photoPaths.map((path) => _PhotoChip(
                      path: path,
                      onRemove: () => setState(
                        () => _photoPaths.remove(path),
                      ),
                    )),
                if (_photoPaths.length < _maxPhotos)
                  ActionChip(
                    avatar: const Icon(Icons.add_a_photo, size: 18),
                    label: Text(l10n.addPhoto),
                    onPressed: _pickPhoto,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.maxPhotos,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),

            // Submit button
            BfButton(
              label: l10n.sendReport,
              onPressed: _submit,
              isLoading: _isSubmitting,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectSelector extends StatelessWidget {
  const _ProjectSelector({
    required this.projects,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Project> projects;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (projects.isEmpty) {
      return Text(
        AppLocalizations.of(context).noActiveProjects,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: projects.map((project) {
        final isSelected = project.id == selectedId;
        return ChoiceChip(
          label: Text(project.name),
          selected: isSelected,
          onSelected: (_) => onSelected(project.id),
          avatar: isSelected
              ? const Icon(Icons.check, size: 18)
              : const Icon(Icons.construction_outlined, size: 18),
        );
      }).toList(),
    );
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PhotoThumbnail(photoId: 'new-$path', url: path, size: 72),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: Theme.of(context).colorScheme.error,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
