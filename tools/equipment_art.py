"""Authored station storage, ventilation and a break-action 12 gauge shotgun."""
import math


def register(api):
    box, rod, wire, gauge = (api[k] for k in ('box', 'rod', 'wire', 'gauge'))

    def shotgun():
        box('Walnut stock', (0, -.025, .23), (.075, .14, .32), 'wood', .025)
        box('Butt pad', (0, -.025, .4), (.08, .145, .025), 'black', .012)
        box('Receiver', (0, .015, .015), (.072, .095, .17), 'steel', .014)
        rod('Barrel', (0, .043, -.06), (0, .043, -.68), .022, 'steel', 24)
        rod('Bore darkness', (0, .043, -.681), (0, .043, -.685), .016, 'black', 24)
        box('Fore end', (0, -.012, -.23), (.068, .065, .25), 'wood', .018)
        for i in range(7):
            box('Grip checkering', (0, -.046, -.14-i*.026), (.071, .005, .008), 'black', .002)
        wire('Trigger guard', [(-.02, -.04, .09), (-.02, -.11, .07), (-.02, -.11, -.015), (-.02, -.04, -.03)], .006, 'steel')
        rod('Trigger', (0, -.035, .025), (0, -.075, .04), .006, 'steel', 8)
        box('Front sight', (0, .071, -.64), (.009, .018, .018), 'cream', .002)
        rod('Hinge pin', (-.042, .005, -.03), (.042, .005, -.03), .012, 'steel', 16)

    def shell():
        rod('Red hull', (0, -.03, 0), (0, .032, 0), .018, 'red', 20)
        rod('Brass head', (0, -.042, 0), (0, -.026, 0), .0195, 'cream', 20)
        rod('Primer', (0, -.043, 0), (0, -.044, 0), .005, 'steel', 12)

    def safe():
        box('Safe rear', (0, 0, -.29), (.86, .85, .08), 'steel', .024)
        for side in [-1, 1]:
            box('Safe wall', (side*.4, 0, 0), (.06, .85, .6), 'steel', .012)
            box('Safe plate', (0, side*.395, 0), (.82, .06, .6), 'steel', .012)
        box('Velvet base', (0, -.355, .02), (.7, .02, .5), 'fabric')

    def safe_door():
        box('Safe door', (0, 0, .32), (.8, .79, .11), 'enamel', .025)
        rod('Dial rim', (0, .08, .39), (0, .08, .43), .11, 'steel', 24)
        rod('Dial', (0, .08, .431), (0, .08, .45), .09, 'black', 24)
        for i in range(12):
            a = i*math.tau/12
            rod('Dial marking', (.074*math.sin(a), .08+.074*math.cos(a), .455), (.087*math.sin(a), .08+.087*math.cos(a), .455), .003, 'cream', 5)
        rod('Safe handle', (.2, -.12, .41), (.2, .12, .41), .025, 'steel', 16)

    def locker_shell():
        box('Locker back', (0, 0, -.27), (.85, 2.1, .06), 'enamel', .014)
        for side in [-1, 1]:
            box('Locker side', (side*.405, 0, 0), (.04, 2.1, .6), 'enamel', .01)
        for y in [-1.02, -.45, .3, 1.02]:
            box('Shelf', (0, y, .01), (.82, .035, .55), 'steel', .008)
        wire('Coat hanger', [(-.25, .75, .01), (0, .9, .01), (.25, .75, .01), (-.25, .75, .01)], .008, 'rust')

    def locker_door():
        box('Locker front', (0, 0, .31), (.81, 2.06, .045), 'enamel', .012)
        box('Label frame', (0, .67, .34), (.29, .14, .016), 'steel', .005)
        box('Paper label', (0, .67, .351), (.24, .09, .004), 'cream')
        for i in range(7):
            box('Vent slit', (0, .4-i*.055, .337), (.46, .012, .01), 'black')
        rod('Handle', (.26, -.08, .37), (.26, .13, .37), .018, 'steel', 12)

    def cage():
        for x in [-.6, .6]:
            for z in [-.4, .4]:
                box('Cage post', (x, 0, z), (.045, 1.9, .045), 'rust', .006)
            for y in [-.93, .93]:
                box('Side rail', (x, y, 0), (.045, .045, .85), 'steel')
            for z in [-.25, -.05, .15]:
                rod('Side bars', (x, -.9, z), (x, .9, z), .012, 'steel', 8)
        for x in [-.4, -.2, 0, .2, .4]:
            rod('Rear bars', (x, -.9, -.4), (x, .9, -.4), .014, 'rust', 8)

    def cage_door():
        for x in [-.58, .58]:
            box('Gate stile', (x, 0, .43), (.045, 1.86, .045), 'steel')
        for y in [-.9, 0, .9]:
            box('Gate rail', (0, y, .43), (1.2, .04, .045), 'rust')
        for x in [-.4, -.2, 0, .2, .4]:
            rod('Gate bars', (x, -.9, .43), (x, .9, .43), .014, 'steel', 8)
        box('Padlock', (.46, -.1, .47), (.08, .11, .04), 'cream', .012)

    def vent_grate():
        box('Grate frame', (0, 0, 0), (1, .8, .05), 'enamel', .018)
        box('Black recess', (0, 0, .035), (.9, .7, .025), 'black')
        for i in range(9):
            box('Louver', (0, -.29+i*.073, .061), (.88, .032, .04), 'steel', .005)
        api['rivets'](0, 0, .087, .92, .72)

    def vent_unit():
        box('Air handler', (0, 0, 0), (1.5, 1.8, .72), 'enamel', .045)
        for y in [-.42, .42]:
            rod('Fan shroud', (0, y, .37), (0, y, .42), .32, 'steel', 32)
            rod('Recess', (0, y, .421), (0, y, .425), .285, 'black', 32)
            for i in range(8):
                a = i*math.tau/8
                rod('Safety cage', (0, y, .45), (.28*math.sin(a), y+.28*math.cos(a), .45), .009, 'steel', 8)
        gauge(.51, .67, -.39, .085)
        wire('Ripped conduit', [(.62, -.7, .4), (.82, -.9, .44), (.8, -1.1, .46)], .03, 'dark_cable')

    return {f.__name__: f for f in [shotgun, shell, safe, safe_door, locker_shell, locker_door, cage, cage_door, vent_unit, vent_grate]}
