import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:async/async.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:llamaseek/Models/model_capabilities.dart';

import 'package:llamaseek/Models/ollama_model.dart';
import 'package:llamaseek/Models/ollama_request_state.dart';
import 'package:llamaseek/Providers/chat_provider.dart';

class ModelSelectionBottomSheet extends StatefulWidget {
  final String title;
  final String? currentModelName;

  const ModelSelectionBottomSheet({
    super.key,
    required this.title,
    this.currentModelName,
  });

  @override
  State<ModelSelectionBottomSheet> createState() =>
      _ModelSelectionBottomSheetState();
}

class _ModelSelectionBottomSheetState extends State<ModelSelectionBottomSheet> {
  static final _modelsBucket = PageStorageBucket();

  late final ChatProvider _chatProvider;

  List<OllamaModel> _models = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  var _state = OllamaRequestState.uninitialized;
  late CancelableOperation _fetchOperation;

  String get _cacheKey {
    final box = Hive.box('settings');
    final isCloud = box.get('isCloudMode', defaultValue: false);
    if (isCloud) return 'cloud';
    return box.get('serverAddress') ?? 'default';
  }

  bool get _isCloudMode =>
      Hive.box('settings').get('isCloudMode', defaultValue: false);

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _models = _modelsBucket.readState(context, identifier: _cacheKey) ?? [];
    _fetchOperation = CancelableOperation.fromFuture(_fetchModels());
  }

  List<OllamaModel> get _filteredModels {
    if (_searchQuery.isEmpty) return _models;
    final query = _searchQuery.toLowerCase();
    return _models.where((m) => m.name.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _fetchOperation.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    setState(() => _state = OllamaRequestState.loading);

    try {
      _models = await _chatProvider.fetchAvailableModels();
      _state = OllamaRequestState.success;
      if (mounted) {
        _modelsBucket.writeState(context, _models, identifier: _cacheKey);
      }
    } catch (e) {
      _state = OllamaRequestState.error;
    }

    if (mounted) setState(() {});
  }

  void _selectModel(OllamaModel model) {
    Navigator.of(context).pop(model);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (_isCloudMode)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_outlined,
                            size: 13, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Cloud',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_models.isNotEmpty &&
                    _state == OllamaRequestState.loading)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Search bar
          if (_models.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(Icons.search,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          const SizedBox(height: 8),
          // Model list
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_state == OllamaRequestState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load models.\nCheck your connection.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  _fetchOperation =
                      CancelableOperation.fromFuture(_fetchModels());
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (_state == OllamaRequestState.loading && _models.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    } else if (_state == OllamaRequestState.success || _models.isNotEmpty) {
      if (_models.isEmpty) {
        return const Center(child: Text('No models found.'));
      }

      final filtered = _filteredModels;
      if (filtered.isEmpty) {
        return Center(
          child: Text(
            'No models match "$_searchQuery"',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          _fetchOperation = CancelableOperation.fromFuture(_fetchModels());
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final model = filtered[index];
            final isCurrent = model.name == widget.currentModelName;
            return _ModelTile(
              model: model,
              isCurrent: isCurrent,
              isCloudMode: _isCloudMode,
              onTap: () => _selectModel(model),
            );
          },
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

class _ModelTile extends StatelessWidget {
  final OllamaModel model;
  final bool isCurrent;
  final bool isCloudMode;
  final VoidCallback onTap;

  const _ModelTile({
    required this.model,
    required this.isCurrent,
    required this.isCloudMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final capabilities = model.capabilities;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isCurrent
            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
            : colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Model info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + size
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.name,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.5,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (model.parameterSize.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                model.parameterSize,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Capability badges
                      if (capabilities != null &&
                          _hasAnyCapability(capabilities))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children:
                                _buildCapabilityBadges(context, capabilities),
                          ),
                        ),
                    ],
                  ),
                ),
                // Checkmark for current model
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasAnyCapability(ModelCapabilities c) =>
      c.vision || c.tools || c.thinking;

  List<Widget> _buildCapabilityBadges(
      BuildContext context, ModelCapabilities capabilities) {
    final badges = <Widget>[];

    if (capabilities.thinking) {
      badges.add(_Badge(
        label: 'Think',
        icon: Icons.auto_awesome,
        color: const Color(0xFF9C6ADE),
      ));
    }
    if (capabilities.vision) {
      badges.add(_Badge(
        label: 'Vision',
        icon: Icons.visibility_rounded,
        color: const Color(0xFF3D8BD4),
      ));
    }
    if (capabilities.tools) {
      badges.add(_Badge(
        label: 'Tools',
        icon: Icons.handyman_rounded,
        color: const Color(0xFFCF8523),
      ));
    }

    return badges;
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a model selection bottom sheet and returns the selected model.
Future<OllamaModel?> showModelSelectionBottomSheet({
  required BuildContext context,
  required String title,
  String? currentModelName,
}) async {
  return await showModalBottomSheet<OllamaModel?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.78),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: ModelSelectionBottomSheet(
                  title: title,
                  currentModelName: currentModelName,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
