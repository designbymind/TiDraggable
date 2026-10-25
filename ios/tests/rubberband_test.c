#include "../Classes/TiDraggableRubberBand.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

int main(void)
{
    const double limit = 48.0, resistance = 0.35;
    assert(TiDraggableRubberBandOffset(0, limit, resistance) == 0);
    assert(TiDraggableRubberBandOffset(-20, limit, resistance) == 0);
    assert(TiDraggableRubberBandOffset(20, 0, resistance) == 0);
    double previous = 0, previousIncrement = limit;
    for (int pull = 1; pull <= 10000; pull++)
    {
        double offset = TiDraggableRubberBandOffset(pull, limit, resistance);
        double increment = offset - previous;
        assert(offset > previous && offset < limit);
        assert(increment <= previousIncrement); // Increasing resistance.
        assert(fabs(TiDraggableRubberBandPull(offset, limit, resistance) - pull) < 1e-7);
        previous = offset;
        previousIncrement = increment;
    }
    // Grabbing an interrupted spring recovers the pull without a visible jump.
    double interrupted = 17.5;
    double resumed = TiDraggableRubberBandPull(interrupted, limit, resistance);
    assert(fabs(TiDraggableRubberBandOffset(resumed, limit, resistance) - interrupted) < 1e-10);
    // Reversing exactly the finger travel returns to the boundary.
    assert(TiDraggableRubberBandOffset(resumed - resumed, limit, resistance) == 0);
    assert(isfinite(TiDraggableRubberBandPull(100, limit, resistance)));
    puts("Rubber-band bounds, resistance, reversal and interruption checks passed.");
}
