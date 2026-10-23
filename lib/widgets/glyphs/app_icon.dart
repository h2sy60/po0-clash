import 'package:material_ui/material_ui.dart';

import 'app_glyphs.dart';
import 'glyph_icon.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color, this.weight});

  final IconData? icon;
  final double? size;
  final Color? color;
  final double? weight;

  @override
  Widget build(BuildContext context) {
    final glyph = switch (icon) {
      Icons.add || Icons.add_rounded => AppGlyphs.add,
      Icons.close => AppGlyphs.close,
      Icons.check || Icons.check_rounded => AppGlyphs.check,
      Icons.more_vert || Icons.more_horiz => AppGlyphs.more,
      Icons.search => AppGlyphs.search,
      Icons.refresh || Icons.refresh_rounded => AppGlyphs.refresh,
      Icons.sync || Icons.sync_rounded => AppGlyphs.sync,
      Icons.sort => AppGlyphs.sort,
      Icons.edit || Icons.edit_rounded => AppGlyphs.edit,
      Icons.delete_outline || Icons.delete_rounded => AppGlyphs.delete,
      Icons.delete_sweep_outlined => AppGlyphs.clearAll,
      Icons.copy || Icons.content_copy_rounded => AppGlyphs.copy,
      Icons.content_paste_rounded => AppGlyphs.paste,
      Icons.qr_code_scanner_rounded => AppGlyphs.qrCode,
      Icons.chevron_right ||
      Icons.chevron_right_rounded => AppGlyphs.chevronForward,
      Icons.expand_more => AppGlyphs.chevronDown,
      Icons.expand_less => AppGlyphs.chevronUp,
      Icons.bolt => AppGlyphs.bolt,
      Icons.adjust => AppGlyphs.target,
      Icons.block => AppGlyphs.block,
      Icons.north_rounded => AppGlyphs.arrowUp,
      Icons.south_rounded => AppGlyphs.arrowDown,
      Icons.shield_rounded ||
      Icons.shield_outlined ||
      Icons.vpn_lock_rounded => AppGlyphs.vpn,
      Icons.key_rounded || Icons.key_off_rounded => AppGlyphs.key,
      Icons.verified_user_rounded => AppGlyphs.verified,
      Icons.schedule_rounded => AppGlyphs.clock,
      Icons.gpp_maybe_rounded => AppGlyphs.warning,
      Icons.public_rounded => AppGlyphs.dns,
      Icons.layers_rounded => AppGlyphs.layers,
      Icons.hub_rounded => AppGlyphs.proxies,
      Icons.lan_rounded ||
      Icons.settings_ethernet_rounded => AppGlyphs.connections,
      Icons.insights_rounded => AppGlyphs.dataUsage,
      Icons.palette_rounded => AppGlyphs.palette,
      Icons.translate_rounded => AppGlyphs.language,
      Icons.tune || Icons.tune_rounded => AppGlyphs.sliders,
      Icons.build_rounded => AppGlyphs.wrench,
      Icons.apps_rounded => AppGlyphs.appsList,
      Icons.lock_open_rounded => AppGlyphs.lockOpen,
      Icons.settings_rounded => AppGlyphs.settings,
      Icons.keyboard_rounded => AppGlyphs.keyboard,
      Icons.cloud_sync_rounded => AppGlyphs.cloudSync,
      Icons.storage_rounded => AppGlyphs.resources,
      Icons.gavel_rounded => AppGlyphs.gavel,
      Icons.info_rounded || Icons.info_outline_rounded => AppGlyphs.info,
      Icons.memory_rounded => AppGlyphs.memory,
      Icons.devices_rounded => AppGlyphs.devices,
      _ => null,
    };
    return glyph == null
        ? Icon(icon, size: size, color: color, weight: weight)
        : GlyphIcon(glyph, size: size, color: color);
  }
}
