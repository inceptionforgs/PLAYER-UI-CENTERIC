import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';
import '../../../services/app_cache_manager.dart';

class LibraryColumn extends StatelessWidget {
  final bool fill;
  final Widget child;

  const LibraryColumn({
    Key? key,
    this.fill = false,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final pane = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: t.textPrimary.withOpacity(0.12)),
        ),
      ),
      child: child,
    );
    if (fill) return Expanded(child: pane);
    return IntrinsicWidth(child: pane);
  }
}

class LibraryFolderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const LibraryFolderRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final fg = selected ? const Color(0xFF101214) : t.textPrimary;
    return Material(
      color: selected ? t.accent : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg.withOpacity(0.8)),
              const SizedBox(width: 10),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, size: 16, color: fg.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryFileRow extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final bool selected;
  final bool folder;
  final VoidCallback onTap;

  const LibraryFileRow({
    Key? key,
    required this.title,
    this.coverUrl,
    this.selected = false,
    this.folder = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final fg = selected ? const Color(0xFF101214) : t.textPrimary;
    return Material(
      color: selected ? t.accent : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: coverUrl != null && coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverUrl!,
                          fit: BoxFit.cover,
                          cacheManager: AppCacheManager.instance,
                          memCacheWidth: 64,
                          memCacheHeight: 64,
                        )
                      : ColoredBox(
                          color: t.surface,
                          child: Icon(Icons.music_note, size: 16, color: fg),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (folder)
                Icon(Icons.chevron_right, size: 16, color: fg.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}