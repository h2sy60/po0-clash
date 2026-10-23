import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/node_profile.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _maxContentWidth = 920.0;

Future<String?> showShareLinksDialog() {
  final appLocalizations = currentAppLocalizations;
  return dialogs.showCommonDialog<String>(
    child: InputDialog(
      title: appLocalizations.shareLinks,
      labelText: appLocalizations.shareLinks,
      hintText: appLocalizations.shareLinksHint,
      value: '',
      keyboardType: TextInputType.multiline,
      validator: (value) => value == null || value.trim().isEmpty
          ? appLocalizations.emptyTip(appLocalizations.shareLinks)
          : null,
    ),
  );
}

class NodesView extends ConsumerWidget {
  const NodesView({super.key});

  Future<void> _importInput(WidgetRef ref) async {
    final action = ref.read(nodeProfileActionProvider.notifier);
    final text = await showShareLinksDialog();
    if (text != null) {
      await action.importWithFeedback(text);
    }
  }

  Future<void> _importClipboard(WidgetRef ref) async {
    final action = ref.read(nodeProfileActionProvider.notifier);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      dialogs.showNotifier(
        currentAppLocalizations.shareLinksInvalid,
        level: MessageLevel.warning,
      );
      return;
    }
    await action.importWithFeedback(text);
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final action = ref.read(nodeProfileActionProvider.notifier);
    final text = system.isDesktop
        ? await globalState.safeRun(picker.pickerConfigQRCode)
        : await BaseNavigator.push<String>(context, const ScanPage());
    if (text != null) {
      await action.importWithFeedback(text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final nodes = ref.watch(nodeProfileNodesProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
    return CommonScaffold(
      title: appLocalizations.manualNodes,
      isLoading: isLoading,
      actions: [
        IconButton(
          tooltip: appLocalizations.clipboardImport,
          onPressed: () => _importClipboard(ref),
          icon: const AppIcon(Icons.content_paste_rounded),
        ),
        IconButton(
          tooltip: appLocalizations.qrcode,
          onPressed: () => _scan(context, ref),
          icon: const AppIcon(Icons.qr_code_scanner_rounded),
        ),
      ],
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassSectionLabel(
                      appLocalizations.nodes,
                      trailing: TextButton.icon(
                        onPressed: () => _importInput(ref),
                        icon: const AppIcon(Icons.add_rounded, size: 18),
                        label: Text(appLocalizations.import),
                      ),
                      padding: const EdgeInsets.fromLTRB(6, 16, 0, 6),
                    ),
                    if (nodes.value case final nodes?)
                      _NodeList(nodes: nodes, onImport: () => _importInput(ref))
                    else if (nodes.error case final error?)
                      Text(
                        userFacingErrorMessage(error, appLocalizations),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.toneColor(GlassTone.danger),
                        ),
                      ),
                    const _ManualNodesTip(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeList extends ConsumerWidget {
  const _NodeList({required this.nodes, required this.onImport});

  final List<ProxyNode> nodes;
  final VoidCallback onImport;

  Future<void> _rename(WidgetRef ref, ProxyNode node) async {
    final appLocalizations = currentAppLocalizations;
    final action = ref.read(nodeProfileActionProvider.notifier);
    final others = {
      for (final other in nodes)
        if (other.nodeName != node.nodeName) other.nodeName,
    };
    final value = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.rename,
        labelText: appLocalizations.nodeName,
        value: node.nodeName,
        keyboardType: TextInputType.text,
        inputFormatters: TextInputLimits.limit(TextInputLimits.name),
        validator: (value) {
          final name = value?.trim() ?? '';
          if (name.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.nodeName);
          }
          if (others.contains(name)) {
            return appLocalizations.nodeNameDuplicate;
          }
          return null;
        },
      ),
    );
    final name = value?.trim();
    if (name == null || name == node.nodeName) {
      return;
    }
    await globalState.safeRun(() => action.renameNode(node.nodeName, name));
  }

  Future<void> _delete(WidgetRef ref, ProxyNode node) async {
    final appLocalizations = currentAppLocalizations;
    final action = ref.read(nodeProfileActionProvider.notifier);
    final confirmed = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.node),
      ),
    );
    if (confirmed != true) {
      return;
    }
    await globalState.safeRun(() => action.deleteNode(node.nodeName));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    if (nodes.isEmpty) {
      return GlassButton(
        padding: const EdgeInsets.all(16),
        onTap: onImport,
        child: Row(
          children: [
            AppIcon(
              Icons.dns_outlined,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appLocalizations.noNodes,
                    style: context.textTheme.titleSmall,
                  ),
                  Text(
                    appLocalizations.manualNodesEmptyDesc,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final node in nodes)
          _NodeItem(
            node: node,
            onRename: () => _rename(ref, node),
            onDelete: () => _delete(ref, node),
          ),
      ],
    );
  }
}

class _NodeItem extends StatelessWidget {
  const _NodeItem({
    required this.node,
    required this.onRename,
    required this.onDelete,
  });

  final ProxyNode node;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return GlassButton(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: onRename,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.nodeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall,
                ),
                Text(
                  '${node.nodeType.toUpperCase()} · ${node.nodeAddress}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontFamily: FontFamily.jetBrainsMono.value,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: appLocalizations.rename,
            onPressed: onRename,
            icon: const AppIcon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: appLocalizations.delete,
            onPressed: onDelete,
            icon: const AppIcon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _ManualNodesTip extends StatelessWidget {
  const _ManualNodesTip();

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.appLocalizations.manualNodesTip,
              style: context.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
