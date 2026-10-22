// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../node_profile.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nodeProfile)
final nodeProfileProvider = NodeProfileProvider._();

final class NodeProfileProvider
    extends $FunctionalProvider<Profile?, Profile?, Profile?>
    with $Provider<Profile?> {
  NodeProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodeProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodeProfileHash();

  @$internal
  @override
  $ProviderElement<Profile?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Profile? create(Ref ref) {
    return nodeProfile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Profile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Profile?>(value),
    );
  }
}

String _$nodeProfileHash() => r'6c8683071827813e7da436afe3cf27fd1c0111de';

@ProviderFor(nodeProfileNodes)
final nodeProfileNodesProvider = NodeProfileNodesProvider._();

final class NodeProfileNodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProxyNode>>,
          List<ProxyNode>,
          FutureOr<List<ProxyNode>>
        >
    with $FutureModifier<List<ProxyNode>>, $FutureProvider<List<ProxyNode>> {
  NodeProfileNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodeProfileNodesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodeProfileNodesHash();

  @$internal
  @override
  $FutureProviderElement<List<ProxyNode>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProxyNode>> create(Ref ref) {
    return nodeProfileNodes(ref);
  }
}

String _$nodeProfileNodesHash() => r'476cfc6d83d93256fe1960789ce6789cb0e738bb';

@ProviderFor(NodeProfileAction)
final nodeProfileActionProvider = NodeProfileActionProvider._();

final class NodeProfileActionProvider
    extends $NotifierProvider<NodeProfileAction, void> {
  NodeProfileActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodeProfileActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodeProfileActionHash();

  @$internal
  @override
  NodeProfileAction create() => NodeProfileAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$nodeProfileActionHash() => r'98056b52cf9214c78fd634bbe4a48dfdc42d1005';

abstract class _$NodeProfileAction extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
