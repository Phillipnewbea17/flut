import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/service_request.dart';
import '../../repositories/requests_repository.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_compressor.dart';
import '../../widgets/big_button.dart';
import '../../widgets/info_card.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/section_title.dart';

/// One page of a request form.
class WizardStep {
  final String title;
  final WidgetBuilder builder;

  /// Returns what is missing, or null when the user may go on.
  final String? Function() validate;

  /// One or two words for the progress bar ("Type of help"). Defaults to
  /// [title].
  final String? shortName;

  /// When set and false, Next is disabled and [blockedHint] is shown under
  /// it (e.g. "Choose one to continue").
  final bool Function()? canContinue;
  final String? blockedHint;

  const WizardStep({
    required this.title,
    required this.builder,
    required this.validate,
    this.shortName,
    this.canContinue,
    this.blockedHint,
  });
}

/// What the form produced, ready for RequestsRepository.create.
class RequestDraft {
  final String title;
  final List<RequestDetail> details;
  final Map<String, String> payload;

  /// Detail label -> the step (index in RequestWizard.steps) where it is
  /// answered. Those details get an "Edit" button on the review page.
  final Map<String, int> editSteps;

  const RequestDraft({
    required this.title,
    required this.details,
    required this.payload,
    this.editSteps = const {},
  });
}

/// A request form, one simple page at a time:
///   [steps]... -> photos (optional) -> review -> submit
/// After submitting it opens the request's page, which says clearly
/// whether the OSCA office received it.
class RequestWizard extends StatefulWidget {
  final String title;
  final RequestKind kind;
  final List<WizardStep> steps;
  final RequestDraft Function() buildDraft;

  /// What photos help (e.g. "prescription, medical certificate").
  /// Null = no photo step.
  final String? photosHint;

  const RequestWizard({
    super.key,
    required this.title,
    required this.kind,
    required this.steps,
    required this.buildDraft,
    this.photosHint,
  });

  /// Opens step [index] of the form around [context] (e.g. a "Change"
  /// button on step 2 that goes back to step 1).
  static void goToStep(BuildContext context, int index) =>
      context.findAncestorStateOfType<_RequestWizardState>()?._goTo(index);

  @override
  State<RequestWizard> createState() => _RequestWizardState();
}

class _RequestWizardState extends State<RequestWizard> {
  static const int _maxPhotos = 5;

  final List<Uint8List> _photos = [];
  int _index = 0;
  String? _error;
  bool _sending = false;

  /// True after "Edit" on the review page: Next goes straight back there.
  bool _returnToReview = false;

  bool get _hasPhotoStep => widget.photosHint != null;
  int get _count => widget.steps.length + (_hasPhotoStep ? 1 : 0) + 1;
  int get _reviewIndex => _count - 1;
  int get _photosIndex => widget.steps.length;
  bool get _onReview => _index == _reviewIndex;
  bool get _onPhotos => _hasPhotoStep && _index == _photosIndex;

  /// The current form page says Next must wait (e.g. nothing chosen yet).
  bool get _blocked =>
      _index < widget.steps.length &&
      !(widget.steps[_index].canContinue?.call() ?? true);

  String get _stepTitle {
    if (_onReview) return 'Check and send';
    if (_onPhotos) return 'Add photos (optional)';
    return widget.steps[_index].title;
  }

  /// Names for the progress bar.
  List<String> get _stepNames => [
        for (final step in widget.steps) step.shortName ?? step.title,
        if (_hasPhotoStep) 'Photos',
        'Review',
      ];

  void _next() {
    if (_index < widget.steps.length) {
      final error = widget.steps[_index].validate();
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _index = _returnToReview ? _reviewIndex : _index + 1;
      if (_index == _reviewIndex) _returnToReview = false;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _returnToReview = false;
      _index--;
    });
  }

  void _goTo(int index) {
    if (_sending || index < 0 || index >= _count) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      // From the review page: come back there after the change.
      if (_onReview && index != _reviewIndex) _returnToReview = true;
      _index = index;
    });
  }

  Future<void> _addPhoto(ImageSource source) async {
    final compressor = context.read<ImageCompressor>();
    try {
      final bytes = await compressor.pickDocument(source);
      if (bytes != null && mounted) setState(() => _photos.add(bytes));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the camera or photos. Please allow access in '
            'your phone settings.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final draft = widget.buildDraft();
    final repo = context.read<RequestsRepository>();
    setState(() => _sending = true);
    final ServiceRequest request;
    try {
      request = await repo.create(
        kind: widget.kind,
        title: draft.title,
        details: draft.details,
        payload: draft.payload,
        photos: List.of(_photos),
      );
    } catch (_) {
      // Saving the photos failed (phone storage full).
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not save your request on this phone. Please free '
              'some space and try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    context.pushReplacement(Routes.request(request.id, justSent: true));
  }

  @override
  Widget build(BuildContext context) {
    final available = context.watch<RequestsRepository>().isAvailable(widget.kind);

    return PopScope(
      // The phone's back button goes to the previous page of the form.
      canPop: _index == 0 && !_sending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0 && !_sending) _back();
      },
      child: Scaffold(
        appBar: AppTheme.appBar(widget.title),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _StepProgress(names: _stepNames, current: _index),
                  const SizedBox(height: 16),
                  SectionTitle(_stepTitle, fontSize: 26),
                  const SizedBox(height: 16),
                  if (_onReview)
                    ..._review(available)
                  else if (_onPhotos)
                    ..._photoStep()
                  else
                    // Builder: the step gets a context below the wizard, so its
                    // buttons can call RequestWizard.goToStep.
                    Builder(builder: widget.steps[_index].builder),
                ],
              ),
            ),
            _ButtonBar(
              error: _error,
              backLabel: _index == 0 ? null : 'Back',
              nextLabel: _onReview
                  ? (_sending
                      ? 'Sending...'
                      : available
                          ? 'Submit request'
                          : 'Save on this phone')
                  : _returnToReview
                      ? 'Back to review'
                      : 'Next',
              nextIcon: _onReview ? Icons.send_outlined : Icons.arrow_forward,
              onBack: _sending ? null : _back,
              onNext: _sending || _blocked
                  ? null
                  : (_onReview ? _submit : _next),
              hint: _blocked ? widget.steps[_index].blockedHint : null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _photoStep() {
    return [
      Text(
        'Photos help the OSCA office check your request faster: '
        '${widget.photosHint}.',
        style: const TextStyle(
            fontSize: 18, color: AppColors.textPrimary, height: 1.4),
      ),
      const SizedBox(height: 16),
      if (_photos.isNotEmpty) ...[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < _photos.length; i++)
              _PhotoThumb(
                bytes: _photos[i],
                onRemove: () => setState(() => _photos.removeAt(i)),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (_photos.length < _maxPhotos)
        Row(
          children: [
            Expanded(
              child: BigButton(
                label: 'Camera',
                icon: Icons.photo_camera_outlined,
                style: BigButtonStyle.tonal,
                onPressed: () => _addPhoto(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BigButton(
                label: 'Gallery',
                icon: Icons.photo_library_outlined,
                style: BigButtonStyle.tonal,
                onPressed: () => _addPhoto(ImageSource.gallery),
              ),
            ),
          ],
        )
      else
        const Text(
          'You added the most photos allowed.',
          style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
        ),
      const SizedBox(height: 12),
      const Text(
        'No photo? You can skip this step.',
        style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
      ),
    ];
  }

  List<Widget> _review(bool available) {
    final draft = widget.buildDraft();
    return [
      InfoCard(
        outlined: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final detail in draft.details)
              _ReviewItem(
                label: detail.label,
                value: detail.value.isEmpty ? '—' : detail.value,
                onEdit: draft.editSteps.containsKey(detail.label)
                    ? () => _goTo(draft.editSteps[detail.label]!)
                    : null,
              ),
            if (_hasPhotoStep)
              _ReviewItem(
                label: 'Photos',
                value: _photos.isEmpty
                    ? 'No photos added'
                    : '${_photos.length} photo${_photos.length == 1 ? '' : 's'} added',
                onEdit: () => _goTo(_photosIndex),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (available)
        const Text(
          'Please check that everything is correct. Tap "Edit" to change '
          'something.',
          style: TextStyle(fontSize: 17, color: AppColors.textPrimary, height: 1.4),
        )
      else
        NoticeCard.notConnected(
          text: '${widget.kind.title} requests cannot be sent from the app '
              'yet. If you continue, your request is saved on this phone '
              'only. It is NOT sent to the OSCA office. Please visit or call '
              'the OSCA office to file it.',
        ),
    ];
  }
}

class _PhotoThumb extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover),
        ),
        Positioned(
          top: -10,
          right: -10,
          child: Material(
            color: AppColors.danger,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Remove photo',
              iconSize: 22,
              color: Colors.white,
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Back" and "Next" at the bottom, always visible above the keyboard.
class _ButtonBar extends StatelessWidget {
  final String? error;
  final String? backLabel;
  final String nextLabel;
  final IconData nextIcon;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  /// Why Next is disabled, shown under the buttons.
  final String? hint;

  const _ButtonBar({
    required this.error,
    required this.backLabel,
    required this.nextLabel,
    required this.nextIcon,
    required this.onBack,
    required this.onNext,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Text(error!, style: OnboardingScaffold.errorText),
                const SizedBox(height: 8),
              ],
              // Back and Next are the same width, and their words stay on
              // one line (they shrink a little with very big text).
              Row(
                children: [
                  if (backLabel != null) ...[
                    Expanded(
                      child: BigButton(
                        label: backLabel!,
                        icon: Icons.arrow_back,
                        style: BigButtonStyle.tonal,
                        singleLine: true,
                        onPressed: onBack,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: BigButton(
                      label: nextLabel,
                      icon: nextIcon,
                      trailingIcon: true,
                      singleLine: true,
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A label above a big text box, for the form pages.
class WizardTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;

  const WizardTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.capitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: maxLines > 1 ? 3 : 1,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

/// Progress bar with the step names; the current step is bold and green.
class _StepProgress extends StatelessWidget {
  final List<String> names;
  final int current;

  const _StepProgress({required this.names, required this.current});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of ${names.length}: ${names[current]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step ${current + 1} of ${names.length}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          // Bars pinned to the same top edge, so they stay level.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < names.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= current
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          names[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                i == current ? FontWeight.w700 : FontWeight.w500,
                            color: i == current
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One answer on the review page, with "Edit" when it can be changed.
class _ReviewItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _ReviewItem({required this.label, required this.value, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton.icon(
              onPressed: onEdit,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.edit_outlined, size: 22),
              label: const Text('Edit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// "You chose: Medicine" with a "Change" button, at the top of a page.
class WizardChosenCard extends StatelessWidget {
  final String text;
  final VoidCallback onChange;

  const WizardChosenCard({super.key, required this.text, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Change', style: OnboardingScaffold.linkText),
          ),
        ],
      ),
    );
  }
}

/// A label above a big dropdown. The last option is always
/// [WizardDropdown.other]; choosing it shows a text box to type it.
class WizardDropdown extends StatelessWidget {
  static const String other = 'Other (type it)';

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final TextEditingController otherController;
  final String otherLabel;

  const WizardDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.otherController,
    this.otherLabel = 'Please type it',
  });

  /// The answer: the option, or what was typed for "Other".
  static String answer(String? value, TextEditingController otherController) =>
      value == other ? otherController.text.trim() : (value ?? '');

  @override
  Widget build(BuildContext context) {
    final all = [...options, other];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            itemHeight: null,
            hint: const Text('Tap to choose', style: TextStyle(fontSize: 20)),
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
            items: [
              for (final option in all)
                DropdownMenuItem(
                  value: option,
                  // Roomy rows in the open list, easy to tap.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(option),
                  ),
                ),
            ],
            // The chosen value inside the box: no extra padding (it would
            // push the words out of the box), and long values wrap.
            selectedItemBuilder: (context) => [
              for (final option in all)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    option,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
          if (value == other) ...[
            const SizedBox(height: 14),
            WizardTextField(
              label: otherLabel,
              controller: otherController,
            ),
          ],
        ],
      ),
    );
  }
}
