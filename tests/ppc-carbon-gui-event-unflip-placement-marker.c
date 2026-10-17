/*
 * Inert placement marker for the PPC event-unflip patch-placement preflight.
 * It has no constructor and is never called by the preflight.
 */
int
rosetta_event_unflip_placement_marker(void)
{
    return 0x504c4143;
}
