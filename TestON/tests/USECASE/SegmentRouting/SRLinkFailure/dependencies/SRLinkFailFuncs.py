"""
Copyright 2017 Open Networking Foundation ( ONF )

Please refer questions to either the onos test mailing list at <onos-test@onosproject.org>,
the System Testing Plans and Results wiki page at <https://wiki.onosproject.org/x/voMg>,
or the System Testing Guide page at <https://wiki.onosproject.org/x/WYQg>

    TestON is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    ( at your option ) any later version.

    TestON is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TestON.  If not, see <http://www.gnu.org/licenses/>.
"""

from tests.USECASE.SegmentRouting.dependencies.Testcaselib import Testcaselib as run

class SRLinkFailFuncs():

    def __init__( self ):
        self.default = ''
        self.topo = dict()
        self.topo[ '0x1' ] = ( 0, 1, '--leaf=1 --spine=0', 'single switch' )
        self.topo[ '2x2' ] = ( 2, 2, '', '2x2 Leaf-spine' )
        self.topo[ '4x4' ] = ( 4, 4, '--leaf=4 --spine=4', '4x4 Leaf-spine' )
        self.switchOne = 'spine101'
        self.switchTwo = 'leaf2'
        self.dpidOne = 'of:0000000000000101'
        self.dpidTwo = 'of:0000000000000002'
        self.portOne = '2'
        self.portTwo = '3'

    def runTest( self, main, caseNum, numNodes, Topo, minFlow ):
        if not hasattr( main, 'apps' ):
            run.initTest( main )

        description = "Bridging and Routing Link Failure test with " + self.topo[ Topo ][ 3 ] + " and {} Onos".format( numNodes )
        main.case( description )

        main.cfgName = Topo
        main.Cluster.setRunningNode( numNodes )
        run.installOnos( main )
        run.loadJson( main )
        run.loadChart( main )
        run.startMininet( main, 'cord_fabric.py', args=self.topo[ Topo ][ 2 ] )
        # pre-configured routing and bridging test
        run.checkFlows( main, minFlowCount=minFlow )
        run.pingAll( main )
        switch = self.topo[ Topo ][ 0 ] + self.topo[ Topo ][ 1 ]
        link = ( self.topo[ Topo ][ 0 ] + self.topo[ Topo ][ 1 ] ) * self.topo[ Topo ][ 0 ]
        # link failure
        run.killLink( main, self.switchOne, self.switchTwo, switches='{}'.format( switch ), links='{}'.format( link - 2 ) )
        run.pingAll( main, "CASE{}_Failure".format( caseNum ) )
        run.restoreLink( main, self.switchOne, self.switchTwo, self.dpidOne,
                         self.dpidTwo, self.portOne, self.portTwo, '{}'.format( switch ), '{}'.format( link ) )
        run.pingAll( main, "CASE{}_Recovery".format( caseNum ) )
        # TODO Dynamic config of hosts in subnet
        # TODO Dynamic config of host not in subnet
        # TODO Dynamic config of vlan xconnect
        # TODO Vrouter integration
        # TODO Mcast integration
        if hasattr( main, 'Mininet1' ):
            run.cleanup( main )
        else:
            # TODO: disconnect TestON from the physical network
            pass
