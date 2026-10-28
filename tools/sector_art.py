"""Industrial sector equipment, exported by build_art.py."""
import math

def register(api):
    box, rod, wire, gauge = (api[k] for k in ('box','rod','wire','gauge'))

    def boiler():
        rod('Pressure vessel', (0,.3,0), (0,2.45,0), .69, 'enamel', 32)
        for y in [.3,2.4]:
            rod('Riveted flange', (0,y-.045,0), (0,y+.045,0), .75, 'steel', 32)
            for i in range(12):
                a=i*math.tau/12
                rod('Flange bolt', (.72*math.sin(a),y-.06,.72*math.cos(a)), (.72*math.sin(a),y+.07,.72*math.cos(a)), .024,'rust',8)
        for x in [-.45,.45]:
            box('Skid leg',(x,.15,0),(.12,.3,1.2),'steel',.015)
        wire('Steam feed',[(.6,2.2,0),(.95,2.2,0),(.95,2.9,0)],.09,'rust')
        wire('Return pipe',[(-.6,.6,0),(-1,.6,0),(-1,.2,0)],.08,'steel')
        gauge(0,1.8,-.72,.15)
        box('Serial plate',(0,1.1,-.7),(.4,.22,.025),'cream',.008)
        for i in range(6):box('Stamped line',(-.12+i*.045,1.1,-.719),(.015,.1,.008),'black')

    def valve():
        rod('Valve spindle',(0,0,-.14),(0,0,.14),.045,'steel',16)
        rod('Mount flange',(0,0,-.17),(0,0,-.11),.17,'steel',24)
        points=[(.27*math.cos(i*math.tau/32),.27*math.sin(i*math.tau/32),.16) for i in range(33)]
        wire('Hand wheel rim',points,.025,'red')
        for i in range(6):
            a=i*math.tau/6
            rod('Wheel spoke',(0,0,.16),(.26*math.cos(a),.26*math.sin(a),.16),.015,'red',10)
        rod('Hub',(0,0,.12),(0,0,.2),.07,'steel',16)
        box('Wheel witness',(0,.27,.17),(.035,.05,.025),'cream',.005)

    def air_filter():
        rod('Filter cartridge',(0,-.17,0),(0,.17,0),.09,'cream',24)
        for y in [-.17,.17]:rod('Rubber gasket',(0,y-.015,0),(0,y+.015,0),.095,'black',24)
        for i in range(20):
            a=i*math.tau/20
            rod('Pleated medium',(.091*math.cos(a),-.14,.091*math.sin(a)),(.091*math.cos(a),.14,.091*math.sin(a)),.007,'fabric',6)
        box('Filter label',(0,0,-.096),(.11,.14,.009),'red',.003)

    return {f.__name__:f for f in [boiler,valve,air_filter]}
