class _QueueDock extends StatefulWidget {
  final bool open;
  final double maxHeight;
  final dynamic t;
  final Color? tint;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onActivity;

  const _QueueDock({
    required this.open,
    required this.maxHeight,
    required this.t,
    required this.tint,
    required this.onOpen,
    required this.onClose,
    required this.onActivity,
  });

  @override
  State<_QueueDock> createState() => _QueueDockState();
}

class _QueueDockState extends State<_QueueDock>
    with SingleTickerProviderStateMixin {
  static const double _collapsedHeight = 56;
  static const Duration _openDur = Duration(milliseconds: 680);
  static const Duration _closeDur = Duration(milliseconds: 560);
  static const Cubic _openCurve = Cubic(0.32, 0.72, 0.0, 1.0);
  static const Cubic _closeCurve = Cubic(0.45, 0.05, 0.2, 1.0);

  late final AnimationController _controller;
  double _overscroll = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _openDur,
      value: widget.open ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _QueueDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      _controller.animateTo(
        widget.open ? 1 : 0,
        duration: widget.open ? _openDur : _closeDur,
        curve: widget.open ? _openCurve : _closeCurve,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _range => widget.maxHeight - _collapsedHeight;

  void _onHeaderDragUpdate(DragUpdateDetails details) {
    widget.onActivity();
    final range = _range;
    if (range <= 0) return;
    final delta = -details.delta.dy / range;
    _controller.value = (_controller.value + delta).clamp(0.0, 1.0);
  }

  void _onHeaderDragEnd(DragEndDetails details) {
    final range = _range;
    final velocity =
        range > 0 ? (details.primaryVelocity ?? 0) / range : 0.0;
    final shouldOpen = velocity < -0.55 ||
        (_controller.value > 0.45 && velocity <= 0.55);

    if (shouldOpen && !widget.open) {
      widget.onOpen();
    } else if (!shouldOpen && widget.open) {
      widget.onClose();
    } else {
      _controller.animateTo(
        widget.open ? 1 : 0,
        duration: widget.open ? _openDur : _closeDur,
        curve: widget.open ? _openCurve : _closeCurve,
      );
    }
  }

  bool _onListOverscroll(ScrollNotification notification) {
    widget.onActivity();
    if (notification is OverscrollNotification) {
      if (notification.overscroll > 0) {
        _overscroll += notification.overscroll;
        if (_overscroll > 48 && widget.open) {
          _overscroll = 0;
          widget.onClose();
        }
      }
    } else if (notification is ScrollEndNotification) {
      _overscroll = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;
    final active = player.currentQueueIndex;
    if (queue.length <= 1) return const SizedBox.shrink();

    final upcoming = <MapEntry<int, Song>>[];
    for (var i = 1; i < queue.length; i++) {
      final index = (active + i) % queue.length;
      upcoming.add(MapEntry(index, queue[index]));
    }
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        final height = _collapsedHeight + _range * value;
        final restT = ((value - 0.12) / 0.52).clamp(0.0, 1.0);

        return SizedBox(
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onHeaderDragUpdate,
            onVerticalDragEnd: _onHeaderDragEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: widget.tint == null
                    ? const Color(0xC7000000)
                    : Color.fromRGBO(
                        (widget.tint!.red * 0.22).round(),
                        (widget.tint!.green * 0.22).round(),
                        (widget.tint!.blue * 0.22).round(),
                        0.92,
                      ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 40,
                    offset: Offset(0, -16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 18,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 36,
                            height: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0x66FFFFFF),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(99)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onListOverscroll,
                        child: ListView.builder(
                          physics: value > 0.88
                              ? const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                )
                              : const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: upcoming.length,
                          itemBuilder: (context, i) {
                            final item = upcoming[i];
                            final tile = i == 0
                                ? _MorphQueueTile(
                                    song: item.value,
                                    t: t,
                                    progress: value,
                                    onTap: () {
                                      context
                                          .read<PlayerProvider>()
                                          .jumpToQueueIndex(item.key);
                                      widget.onClose();
                                    },
                                  )
                                : _QueueTile(
                                    song: item.value,
                                    t: t,
                                    onTap: () {
                                      context
                                          .read<PlayerProvider>()
                                          .jumpToQueueIndex(item.key);
                                      widget.onClose();
                                    },
                                  );
                            if (i == 0) return tile;
                            return Opacity(
                              opacity: restT,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - restT)),
                                child: tile,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MorphQueueTile extends StatelessWidget {
  final Song song;
  final dynamic t;
  final double progress;
  final VoidCallback onTap;

  const _MorphQueueTile({
    required this.song,
    required this.t,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final h = 38 + 58 * p;
    final cover = 36 + 60 * p;
    final radius = 8 * (1 - p);
    final titleSize = 13 + 5 * p;
    final upNext = (1 - p * 1.55).clamp(0.0, 1.0);
    final singerOp = ((p - 0.28) / 0.5).clamp(0.0, 1.0);
    final title = (song.titleHindi?.trim().isNotEmpty ?? false)
        ? song.titleHindi!
        : song.title;
    final url = song.coverImageUrl;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: h,
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 12 * (1 - p)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: cover,
                  height: cover,
                  child: url != null && url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          width: cover,
                          height: cover,
                          cacheManager: AppCacheManager.instance,
                          memCacheWidth: 192,
                          memCacheHeight: 192,
                        )
                      : ColoredBox(
                          color: Colors.white10,
                          child: Icon(Icons.music_note, color: t.textPrimary),
                        ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 + 4 * p),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (upNext > 0.02)
                      Opacity(
                        opacity: upNext,
                        child: Text(
                          'UP NEXT',
                          style: TextStyle(
                            color: t.textPrimary.withOpacity(0.55),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: titleSize,
                        fontWeight: FontWeight.lerp(
                          FontWeight.w600,
                          FontWeight.w700,
                          p,
                        ),
                        height: 1.2,
                      ),
                    ),
                    if (singerOp > 0.02)
                      Opacity(
                        opacity: singerOp,
                        child: Text(
                          song.singerName ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.textPrimary.withOpacity(0.62),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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

class _MiniCover extends StatelessWidget {
  final String? url;

  const _MiniCover({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: ColoredBox(color: Colors.white10),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      cacheManager: AppCacheManager.instance,
      memCacheWidth: 72,
      memCacheHeight: 72,
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Song song;
  final dynamic t;
  final VoidCallback onTap;

  const _QueueTile({
    required this.song,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            if (song.coverImageUrl != null && song.coverImageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: song.coverImageUrl!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                cacheManager: AppCacheManager.instance,
                memCacheWidth: 192,
                memCacheHeight: 192,
              )
            else
              SizedBox(
                width: 96,
                height: 96,
                child: Icon(Icons.music_note, color: t.textPrimary),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (song.titleHindi?.trim().isNotEmpty ?? false)
                          ? song.titleHindi!
                          : song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if ((song.titleHindi?.trim().isNotEmpty ?? false) &&
                        song.titleHindi != song.title) ...[
                      const SizedBox(height: 2),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textPrimary.withOpacity(0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      song.singerName ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary.withOpacity(0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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