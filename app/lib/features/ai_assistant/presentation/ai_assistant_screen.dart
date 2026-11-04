import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/ai/ai.dart';
import '../../../core/api/api_error.dart';
import '../../documents/presentation/widgets/attachments_card.dart';
import 'widgets/draft_review_card.dart';

/// AI Assistant: describe what happened (or show a receipt) and get a draft.
/// Drafts are reviewed and approved here; nothing is saved automatically.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      refreshDrafts(ref);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, 'The assistant could not create a draft.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromText() async {
    final text = _text.text.trim();
    if (text.length < 2) return;
    await _run(() async {
      await ref.read(aiRepositoryProvider).draftFromText(requireWorkspaceIdFromWidget(ref), text);
      _text.clear();
    });
  }

  Future<void> _fromReceipt() async {
    final attachment = await pickAndUploadDocument(context, ref, module: 'GENERAL');
    if (attachment == null) return;
    await _run(() => ref.read(aiRepositoryProvider).draftFromReceipt(requireWorkspaceIdFromWidget(ref), attachment.id));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI Assistant', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Write in English, Urdu or Roman Urdu. The assistant prepares a draft; you check it and approve. Nothing is saved without your approval.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _text,
                      enabled: !_busy,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'e.g. "2 bakriyan 90 hazar me bechi, paise cash me aaye" or "Sultan ka wazan 42 kg"',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _fromText(),
                    ),
                    if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _fromText,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Create draft'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _fromReceipt,
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('Read a receipt'),
                        ),
                        if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [Tab(text: 'To review'), Tab(text: 'Approved'), Tab(text: 'Rejected')],
            ),
            const Expanded(child: TabBarView(children: [_DraftList('PENDING'), _DraftList('APPROVED'), _DraftList('REJECTED')])),
          ],
        ),
      ),
    );
  }
}

class _DraftList extends ConsumerWidget {
  const _DraftList(this.status);
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider(status));
    return drafts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load drafts.'))),
      data: (list) => list.isEmpty
          ? Center(child: Text(status == 'PENDING' ? 'No drafts waiting for review.' : 'Nothing here yet.'))
          : ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [for (final d in list) DraftReviewCard(key: ValueKey('${d.id}-${d.status}'), draft: d)],
            ),
    );
  }
}
