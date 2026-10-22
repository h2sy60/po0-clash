import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/node_profile.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'action.dart';
import 'config.dart';
import 'core.dart';
import 'database.dart';

part 'generated/node_profile.g.dart';

@riverpod
Profile? nodeProfile(Ref ref) {
  final id = ref.watch(nodeProfileIdProvider);
  return ref.watch(
    profilesProvider.select((profiles) => profiles.getProfile(id)),
  );
}

@riverpod
Future<List<ProxyNode>> nodeProfileNodes(Ref ref) {
  return _nodesOf(ref.watch(nodeProfileProvider));
}

Future<List<ProxyNode>> _nodesOf(Profile? profile) async {
  if (profile == null) {
    return [];
  }
  return nodesOfProfile(await (await profile.file).readAsString());
}

@Riverpod(keepAlive: true)
class NodeProfileAction extends _$NodeProfileAction {
  NodeProfileTemplate? _template;
  Future<void> _tail = Future.value();

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  void build() {}

  Future<void> importWithFeedback(String text) async {
    final appLocalizations = currentAppLocalizations;
    final merge = await globalState.loadingRun(
      () => importShareLinks(text),
      tag: LoadingTag.profiles,
      title: appLocalizations.shareLinks,
    );
    if (merge == null) {
      return;
    }
    if (merge.added == 0) {
      dialogs.showNotifier(appLocalizations.nodesAlreadyExist);
      return;
    }
    dialogs.showNotifier(
      merge.skipped == 0
          ? appLocalizations.nodesImported(merge.added)
          : appLocalizations.nodesImportedSkipped(merge.added, merge.skipped),
      level: MessageLevel.success,
    );
  }

  Future<NodeMerge> importShareLinks(String text) => _serial(() async {
    final incoming = await _core.convertShareLinks(text);
    if (incoming.isEmpty) {
      throw MessageException(currentAppLocalizations.shareLinksInvalid);
    }
    final template = await _loadTemplate();
    final merge = mergeNodes(
      await _nodesOf(ref.read(nodeProfileProvider)),
      incoming,
      reservedNames: template.reservedNames,
    );
    if (merge.added > 0) {
      await _save(template, merge.nodes);
    }
    return merge;
  });

  Future<void> renameNode(String from, String to) => _serial(() async {
    final template = await _loadTemplate();
    final nodes = await _nodesOf(ref.read(nodeProfileProvider));
    final taken = {
      ...template.reservedNames,
      for (final node in nodes)
        if (node.nodeName != from) node.nodeName,
    };
    if (taken.contains(to)) {
      throw MessageException(currentAppLocalizations.nodeNameDuplicate);
    }
    await _save(
      template,
      [
        for (final node in nodes)
          node.nodeName == from ? {...node, 'name': to} : node,
      ],
      selectedMap: (selected) => selected.map(
        (group, proxy) => MapEntry(group, proxy == from ? to : proxy),
      ),
    );
  });

  Future<void> deleteNode(String name) => _serial(() async {
    final template = await _loadTemplate();
    final nodes = await _nodesOf(ref.read(nodeProfileProvider));
    await _save(
      template,
      [
        for (final node in nodes)
          if (node.nodeName != name) node,
      ],
      selectedMap: (selected) =>
          {...selected}..removeWhere((_, proxy) => proxy == name),
    );
  });

  // Every change rewrites the whole profile file from what it read, so changes
  // must not interleave.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<NodeProfileTemplate> _loadTemplate() async {
    return _template ??= NodeProfileTemplate(
      await rootBundle.loadString(nodeProfileTemplateAsset),
    );
  }

  Future<void> _save(
    NodeProfileTemplate template,
    List<ProxyNode> nodes, {
    Map<String, String> Function(Map<String, String> selected)? selectedMap,
  }) async {
    final current = ref.read(nodeProfileProvider);
    final saved =
        await (current ??
                Profile.normal(label: currentAppLocalizations.manualNodes))
            .saveFile(
              utf8.encode(template.render(nodes)),
              validate: _core.validateConfig,
            );
    final profile = selectedMap == null
        ? saved
        : saved.copyWith(selectedMap: selectedMap(saved.selectedMap));
    final profilesAction = ref.read(profilesActionProvider.notifier);
    if (current == null) {
      ref.read(nodeProfileIdProvider.notifier).value = profile.id;
      profilesAction.putProfile(profile);
    } else {
      profilesAction.setProfileAndAutoApply(profile);
    }
  }
}
