import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/photo_draft.dart';
import 'package:buildflow/core/photos/photo_picking.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/core/widgets/bf_icon_button.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/core/widgets/photo_draft_tile.dart';
import 'package:buildflow/core/widgets/retry_delete_sheet.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

const _maxPhotos = 5;

/// Appends a quick template to the report text: «Залили» + «Бетон» →
/// «Залили, бетон»; an empty text or a finished sentence gets the word as is.
@visibleForTesting
String appendTemplate(String text, String word) {
  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return word;
  if (RegExp(r'[.!?]$').hasMatch(trimmed)) return '$trimmed $word';
  final lower =
      word.characters.first.toLowerCase() + word.characters.skip(1).toString();
  return '$trimmed, $lower';
}

/// New report screen — select project, add photos + text, submit.
class NewReportScreen extends ConsumerStatefulWidget {
  const NewReportScreen({this.initialProjectId, super.key});

  /// Preselected project, e.g. when opened from a project page.
  final String? initialProjectId;

  @override
  ConsumerState<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends ConsumerState<NewReportScreen> {
  final _textController = TextEditingController();
  late String? _selectedProjectId = widget.initialProjectId;

  /// This screen's own photos: the tab and a copy opened on top of a
  /// project page don't share them.
  final _photoScope = 'report:${const Uuid().v4()}';
  bool _isSubmitting = false;

  PhotoDraftsNotifier get _photos =>
      ref.read(photoDraftsProvider(_photoScope).notifier);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The button is disabled only after the next rebuild, so a second tap
    // in the same frame still lands here.
    if (_isSubmitting) return;
    if (_selectedProjectId == null) {
      _showSnackBar(AppLocalizations.of(context).selectProjectHint);
      return;
    }
    if (_textController.text.trim().isEmpty) {
      _showSnackBar(AppLocalizations.of(context).reportTextHint);
      return;
    }

    setState(() => _isSubmitting = true);

    // Photos still being compressed are waited for; one that failed stops
    // the report until it's retried or removed.
    final photos = await _photos.whenReady();
    final result = switch (photos) {
      Success(:final data) =>
        await ref.read(reportsProvider.notifier).submitReport(
              projectId: _selectedProjectId!,
              text: _textController.text.trim(),
              photos: data,
            ),
      Err(:final failure) => Err<Report>(failure),
    };

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    final l10n = AppLocalizations.of(context);

    switch (result) {
      case Success():
        _showSnackBar(l10n.reportSent);
        // Opened on top of a project page — go back to it. The photos
        // belong to the report now: leaving drops only the originals.
        if (widget.initialProjectId != null && Navigator.of(context).canPop()) {
          _photos.clear();
          Navigator.of(context).pop();
          return;
        }
        _textController.clear();
        _photos.clear();
        setState(() => _selectedProjectId = null);
      case Err(:final failure):
        // The form keeps its text and photos, so the foreman can resend.
        _showSnackBar(l10n.reportError(l10n.failureMessage(failure)));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = ref.read(photoDraftsProvider(_photoScope)).length;
    final paths = await pickPhotos(
      context,
      source: source,
      limit: _maxPhotos - picked,
    );
    if (mounted) _photos.add(paths);
  }

  Future<void> _onFailedPhoto(PhotoDraft draft) async {
    final retry = await showRetryDeleteSheet(
      context,
      title: AppLocalizations.of(context).photoProcessingFailed,
    );
    if (!mounted || retry == null) return;
    retry ? _photos.retry(draft.id) : _photos.remove(draft.id);
  }

  void _addTemplate(String word) {
    final text = appendTemplate(_textController.text, word);
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _chooseProject(List<Project> projects) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ProjectSheet(projects: projects, selectedId: _selectedProjectId),
    );
    if (id != null && mounted) setState(() => _selectedProjectId = id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final projects = ref.watch(projectsProvider);
    final photos = ref.watch(photoDraftsProvider(_photoScope));
    final canAddPhoto = photos.length < _maxPhotos;
    final sectionStyle = theme.textTheme.labelMedium?.copyWith(
      color: t.textSecondary,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              onClose: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  0,
                  AppTheme.screenPadding,
                  AppTheme.spacing24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Project
                    Text(l10n.stepProject, style: sectionStyle),
                    const SizedBox(height: AppTheme.spacing8),
                    projects.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(l10n.failureMessage(e)),
                      data: (list) {
                        final active = list
                            .where((p) => p.status.isActive)
                            .toList();
                        if (active.isEmpty) {
                          return Text(
                            l10n.noActiveProjects,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: t.textSecondary,
                            ),
                          );
                        }
                        return _ProjectButton(
                          project: active
                              .where((p) => p.id == _selectedProjectId)
                              .firstOrNull,
                          onTap: () => _chooseProject(active),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Photos
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.stepPhotos,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          l10n.photoCounter(photos.length, _maxPhotos),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: t.textSecondary,
                            fontFeatures: AppTextTheme.tabular,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    _PhotoGrid(
                      photos: photos,
                      onRemove: (draft) => _photos.remove(draft.id),
                      onFailedTap: _onFailedPhoto,
                      onGallery: canAddPhoto
                          ? () => _pickPhoto(ImageSource.gallery)
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    BfButton(
                      label: l10n.takePhotoButton,
                      icon: Icons.photo_camera_rounded,
                      variant: BfButtonVariant.secondary,
                      onPressed: canAddPhoto
                          ? () => _pickPhoto(ImageSource.camera)
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Report text
                    BfTextField(
                      label: l10n.reportWhatDone,
                      hint: l10n.reportTextHint,
                      controller: _textController,
                      maxLines: 6,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Wrap(
                      spacing: AppTheme.spacing8,
                      children: [
                        for (final word in [
                          l10n.templateConcrete,
                          l10n.templateRebar,
                          l10n.templateMasonry,
                          l10n.templateMaterials,
                        ])
                          BfChip(
                            label: word,
                            icon: Icons.add_rounded,
                            onTap: () => _addTemplate(word),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Pinned submit button
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.canvas,
                border: Border(top: BorderSide(color: t.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  AppTheme.spacing12,
                  AppTheme.screenPadding,
                  AppTheme.spacing12,
                ),
                child: BfButton(
                  label: l10n.sendReport,
                  onPressed: _submit,
                  isLoading: _isSubmitting,
                  icon: Icons.send_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  /// `null` when the screen is a navigation tab and has nothing to close.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spacing16,
        AppTheme.screenPadding,
        AppTheme.spacing16,
      ),
      child: Row(
        children: [
          if (onClose != null) ...[
            BfIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.close,
              onPressed: onClose,
            ),
            const SizedBox(width: AppTheme.spacing12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.reportForToday,
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                Text(
                  DateFormatter.dayMonthYear(DateTime.now()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.bfTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Project ───────────────────────────────────────────────────

class _ProjectButton extends StatelessWidget {
  const _ProjectButton({required this.project, required this.onTap});

  final Project? project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    return BfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.muted,
              borderRadius: BorderRadius.circular(
                BuildFlowThemeExtension.photoRadius,
              ),
            ),
            child: Icon(Icons.construction_rounded, color: t.textPrimary),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: project == null
                ? Text(
                    l10n.selectProject,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: t.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project!.name, style: theme.textTheme.titleMedium),
                      Text(
                        project!.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          Icon(Icons.expand_more_rounded, color: t.textSecondary),
        ],
      ),
    );
  }
}

/// Active projects to report on. Pops the chosen project id.
class _ProjectSheet extends StatelessWidget {
  const _ProjectSheet({required this.projects, required this.selectedId});

  final List<Project> projects;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Text(
                l10n.selectProject,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in projects)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.screenPadding,
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.address),
                      trailing: p.id == selectedId
                          ? Icon(Icons.check_circle_rounded, color: t.accent)
                          : null,
                      onTap: () => Navigator.pop(context, p.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photos ────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onRemove,
    required this.onFailedTap,
    required this.onGallery,
  });

  static const _columns = 3;
  static const _gap = 8.0;

  final List<PhotoDraft> photos;
  final ValueChanged<PhotoDraft> onRemove;
  final ValueChanged<PhotoDraft> onFailedTap;

  /// `null` once the photo limit is reached.
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final draft in photos)
              PhotoDraftTile(
                key: ValueKey(draft.id),
                draft: draft,
                size: size,
                onRemove: () => onRemove(draft),
                onFailedTap: () => onFailedTap(draft),
              ),
            if (onGallery != null) _GalleryCell(size: size, onTap: onGallery!),
          ],
        );
      },
    );
  }
}

class _GalleryCell extends StatelessWidget {
  const _GalleryCell({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final radius = BorderRadius.circular(BuildFlowThemeExtension.photoRadius);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: t.textTertiary,
          radius: BuildFlowThemeExtension.photoRadius,
        ),
        child: Material(
          color: t.muted.withValues(alpha: 0.5),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 28,
                  color: t.textSecondary,
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  AppLocalizations.of(context).fromGallery,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle outline.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  static const _dash = 6.0;
  static const _gap = 4.0;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(radius),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
