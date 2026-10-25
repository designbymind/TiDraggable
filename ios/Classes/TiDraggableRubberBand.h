#ifndef TiDraggableRubberBand_h
#define TiDraggableRubberBand_h

// Keep the uncompressed pull separate from the displayed offset so resistance
// depends on finger travel, rather than the number of gesture callbacks.
static inline double TiDraggableRubberBandOffset(double pull, double limit, double resistance)
{
    if (pull <= 0.0 || limit <= 0.0 || resistance <= 0.0) return 0.0;
    return limit * (1.0 - 1.0 / (1.0 + resistance * pull / limit));
}

static inline double TiDraggableRubberBandPull(double offset, double limit, double resistance)
{
    if (offset <= 0.0 || limit <= 0.0 || resistance <= 0.0) return 0.0;
    // A newly configured smaller limit can be below the interrupted offset.
    if (offset >= limit) offset = limit * 0.999;
    return offset / (resistance * (1.0 - offset / limit));
}

#endif
