package pass1

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"maps"
	"slices"
	"strings"

	"github.com/hknutzen/Netspoc/go/pkg/conf"
	"github.com/hknutzen/Netspoc/go/pkg/oslink"
	"github.com/spf13/pflag"
)

func ExportNetvisMain(d oslink.Data) int {
	fs := pflag.NewFlagSet(d.Args[0], pflag.ContinueOnError)

	// Setup custom usage function.
	fs.Usage = func() {
		fmt.Fprintf(d.Stderr,
			"Usage: %s [options] FILE|DIR\n%s",
			d.Args[0], fs.FlagUsages())
	}

	// Command line flags
	quiet := fs.BoolP("quiet", "q", false, "Don't print progress messages")
	if err := fs.Parse(d.Args[1:]); err != nil {
		if errors.Is(err, pflag.ErrHelp) {
			return 1
		}
		fmt.Fprintf(d.Stderr, "Error: %s\n", err)
		fs.Usage()
		return 1
	}

	// Argument processing
	args := fs.Args()
	if len(args) != 1 {
		fs.Usage()
		return 1
	}
	path := args[0]

	cnf := conf.ConfigFromFile(path)
	cnf.Quiet = *quiet

	return toplevelSpoc(d, cnf, func(c *spoc) {
		c.exportNetvis(d.Stdout, path)
	})
}

type visBase struct {
	Id        string        `json:"id"`
	Type      string        `json:"type"`
	InArea    string        `json:"in_area,omitempty"`
	Address   string        `json:"address,omitempty"`
	Address2  string        `json:"address2,omitempty"`
	Neighbors []visNeighbor `json:"neighbors"`
}

type visNeighbor struct {
	Id            string `json:"id"`
	NeighborCount int    `json:"neighbor_count"`
	IsTunnel      bool   `json:"is_tunnel,omitempty"`
}
type visNetwork struct {
	visBase
	Hosts []string `json:"hosts"`
}

type visRouter = visBase

type visArea struct {
	Id              string   `json:"id"`
	Type            string   `json:"type"`
	InArea          string   `json:"in_area,omitempty"`
	Border          []string `json:"border,omitempty"`
	InclusiveBorder []string `json:"inclusive_border,omitempty"`
	Networks        []string `json:"networks"`
	Routers         []string `json:"routers"`
	ChildAreas      []string `json:"child_areas,omitempty"`
	Neighbors       []string `json:"neighbors,omitempty"`
}

func (c *spoc) exportNetvis(stdout io.Writer, path string) {
	c.readNetspoc(path)
	c.setZone()
	networks := make(map[string]visNetwork)
	routers := make(map[string]visRouter)
	areas := make(map[string]visArea)

	// Determine the area each router belongs to.
	home := c.routerHome()

	// Areas and networks sorted by name, for deterministic output.
	areaList := slices.SortedFunc(maps.Values(c.symTable.area),
		func(a, b *area) int { return strings.Compare(a.name, b.name) })
	netList := slices.SortedFunc(maps.Values(c.symTable.network),
		func(a, b *network) int { return strings.Compare(a.name, b.name) })
	routerList := slices.SortedFunc(maps.Values(c.symTable.router),
		func(a, b *router) int { return strings.Compare(a.name, b.name) })

	// Map each area boundary interface to the areas it is border of,
	// ordered by area name.
	roleInAreas := make(map[*routerIntf][]*area)
	addRole := func(intf *routerIntf, a *area) {
		for _, x := range roleInAreas[intf] {
			if x == a {
				return
			}
		}
		roleInAreas[intf] = append(roleInAreas[intf], a)
	}
	for _, a := range areaList {
		for _, intf := range a.border {
			addRole(intf, a)
		}
		for _, intf := range a.inclusiveBorder {
			addRole(intf, a)
		}
	}

	// Build maps of child areas and networks for each area, for deterministic output.
	childAreas := make(map[*area][]*area)
	for _, b := range areaList {
		if a := b.inArea; a != nil {
			childAreas[a] = append(childAreas[a], b)
		}
	}
	areaNetworks := make(map[*area][]*network)
	for _, n := range netList {
		if a := n.zone.inArea; a != nil {
			areaNetworks[a] = append(areaNetworks[a], n)
		}
	}
	// Neighboring objects of each area and their number.
	neighborList := make(map[*area][]string)
	for _, a := range areaList {
		if l := areaNeighborsReal(a, home); l != nil {
			neighborList[a] = l
		}
	}
	areaCount := make(map[*area]int)
	for _, a := range areaList {
		areaCount[a] = areaNeighborCount(a, neighborList)
	}

	for _, a := range areaList {
		areas[a.name] = getVisArea(a, home, routerList, neighborList[a], childAreas[a], areaNetworks[a])
	}

	for _, n := range c.symTable.network {
		getVisNetwork(n, networks, home, roleInAreas, areaCount)
	}
	for _, r := range c.symTable.router {
		getVisRouter(r, home, roleInAreas, areaCount, routers)
	}
	data := struct {
		Network map[string]visNetwork `json:"network"`
		Router  map[string]visRouter  `json:"router"`
		Area    map[string]visArea    `json:"area"`
	}{
		networks, routers, areas,
	}
	out, _ := json.Marshal(data)
	fmt.Fprintln(stdout, string(out))

}

// areaNeighborsReal determines the real neighboring objects of an area,
// i.e. the networks and routers on the other side of its borders.
// An area only looks beyond its inclusive borders, if it has some.
// A neighboring area on the other side is reported as well, but not
// an enclosing or enclosed area.
// Areas are reported first, all objects sorted by name.
func areaNeighborsReal(a *area, home map[*router]*area) []string {
	var srcs []*routerIntf
	useInclusive := len(a.inclusiveBorder) > 0
	if useInclusive {
		srcs = a.inclusiveBorder
	} else {
		srcs = a.border
	}

	var ids []string
	seen := make(map[string]bool)
	add := func(id string) {
		if !seen[id] {
			seen[id] = true
			ids = append(ids, id)
		}
	}
	// Report area x as neighbor, if it is not identical with area a
	// and neither encloses a nor is enclosed by a.
	includeArea := func(x *area) bool {
		return x != nil && x != a && !areaIsAncestor(x, a) && !areaIsAncestor(a, x)
	}
	for _, intf := range srcs {
		if useInclusive {
			n := intf.network
			add(n.name)
			if x := n.zone.inArea; includeArea(x) {
				add(x.name)
			}
		} else {
			r := intf.router
			if r.origRouter != nil {
				r = r.origRouter
			}
			add(r.name)
			if x := home[r]; includeArea(x) {
				add(x.name)
			}
		}
	}
	// Sort area neighbors before network/router neighbors,
	// all by name.
	slices.SortFunc(ids, func(x, y string) int {
		xArea, yArea := isAreaID(x), isAreaID(y)
		if xArea != yArea {
			if xArea {
				return -1
			}
			return 1
		}
		return strings.Compare(x, y)
	})
	return ids
}

// isAreaID returns true, if id denotes an area.
func isAreaID(id string) bool {
	return strings.HasPrefix(id, "area:")
}

// routerHome determines the area each router belongs to.
// A managed router belongs to the smallest area it is a managed router of.
// A managed router belongs to an area only as member of this area,
// not because it borders on it.
// Any other router belongs to the smallest area of its interfaces.
func (c *spoc) routerHome() map[*router]*area {
	home := make(map[*router]*area)
	// ascendingAreas is sorted by size then by name, so the first area
	// found is the smallest one.
	for _, a := range c.ascendingAreas {
		for _, r := range a.managedRouters {
			if _, found := home[r]; !found {
				home[r] = a
			}
		}
	}
	// Routers without managed area.
	for _, r := range c.symTable.router {
		if r.managed != "" {
			continue
		}
		if _, found := home[r]; found {
			continue
		}
		intfs := r.origIntfs
		if intfs == nil {
			intfs = r.interfaces
		}
		for _, intf := range intfs {
			if a := intf.network.zone.inArea; a != nil {
				if cur := home[r]; cur == nil || areaSmaller(a, cur) {
					home[r] = a
				}
			}
		}
	}
	return home
}

// areaSmaller returns true, if area a is smaller than area b,
// or has equal size and a smaller name.
func areaSmaller(a, b *area) bool {
	sa, sb := areaSize(a), areaSize(b)
	return sa < sb || (sa == sb && strings.Compare(a.name, b.name) < 0)
}

func areaSize(a *area) int {
	return len(a.zones) + len(a.managedRouters)
}

// areaIsAncestor returns true, if area a is strictly nested in area b.
func areaIsAncestor(a, b *area) bool {
	if a == nil {
		return false
	}
	for up := a.inArea; up != nil; up = up.inArea {
		if up == b {
			return true
		}
	}
	return false
}

// getVisArea creates the visArea node for an area. Routers are listed if
// the area is their home area. The routers, networks, child areas and
// neighbors of the area are passed in as precomputed lists in
// deterministic order.
func getVisArea(a *area, home map[*router]*area, routerList []*router, neighbors []string, childAreas []*area, networks []*network) visArea {
	node := visArea{
		Id:   a.name,
		Type: "area",
	}
	if a.inArea != nil {
		node.InArea = a.inArea.name
	}
	for _, intf := range a.border {
		node.Border = append(node.Border, intf.name)
	}
	for _, intf := range a.inclusiveBorder {
		node.InclusiveBorder = append(node.InclusiveBorder, intf.name)
	}
	// A network is part of an area if its zone is in the area. The networks
	// list is precomputed from zone.inArea, not from a.zones, because
	// networks next to a crypto hub are not tracked in a.zones.
	for _, n := range networks {
		node.Networks = append(node.Networks, n.name)
	}
	seen := make(map[*router]bool)
	addRouter := func(r *router) {
		// A crypto hub is split into a separate router instance named
		// after its interface. Report the original router instead.
		if r.origRouter != nil {
			r = r.origRouter
		}
		if seen[r] || home[r] != a {
			return
		}
		seen[r] = true
		node.Routers = append(node.Routers, r.name)
	}
	// List all routers whose home area is this area. Besides managed and
	// border routers this includes unmanaged routers that are simply
	// located inside the area. routerList is sorted by name, so the
	// result is deterministic.
	for _, r := range routerList {
		addRouter(r)
	}
	node.Neighbors = neighbors
	for _, b := range childAreas {
		node.ChildAreas = append(node.ChildAreas, b.name)
	}
	return node
}

// routerNeighborCount counts the interfaces of a router, increased by
// the number of areas the router is a border router of, excluding its
// home area and enclosing areas.
func routerNeighborCount(r *router, home map[*router]*area, roleInAreas map[*routerIntf][]*area) int {
	if r.origRouter != nil {
		r = r.origRouter
	}
	count := len(r.interfaces)
	h := home[r]
	seen := make(map[string]bool)
	for _, intf := range r.interfaces {
		for _, a := range roleInAreas[intf] {
			if seen[a.name] || a == h || areaIsAncestor(h, a) {
				continue
			}
			seen[a.name] = true
			count++
		}
	}
	return count
}

// networkNeighborCount counts the interfaces of a network, increased by
// the number of areas that have one of the interfaces as border,
// excluding the network's own area and enclosing areas.
func networkNeighborCount(n *network, roleInAreas map[*routerIntf][]*area) int {
	count := len(n.interfaces)
	a := n.zone.inArea
	seen := make(map[string]bool)
	for _, intf := range n.interfaces {
		for _, x := range roleInAreas[intf] {
			if seen[x.name] || x == a || areaIsAncestor(a, x) {
				continue
			}
			seen[x.name] = true
			count++
		}
	}
	return count
}

// areaNeighborCount counts the borders of an area, increased by the
// number of neighboring areas.
func areaNeighborCount(a *area, neighborList map[*area][]string) int {
	count := len(a.border) + len(a.inclusiveBorder)
	for _, id := range neighborList[a] {
		if isAreaID(id) {
			count++
		}
	}
	return count
}

func getVisNetwork(net *network, networks map[string]visNetwork, home map[*router]*area, roleInAreas map[*routerIntf][]*area, areaCount map[*area]int) {
	var node visNetwork
	node.Id = net.name
	node.Type = "network"
	if net.ipType != unnumberedIP {
		node.Address = net.ipp.String()
		if net2 := net.combined46; net2 != nil {
			node.Address2 = net2.ipp.String()
		}
	}

	if a := net.zone.inArea; a != nil {
		node.InArea = a.name
	}

	getVisNeigh := func(intf *routerIntf) visNeighbor {
		r := intf.router
		if r.origRouter != nil {
			r = r.origRouter
		}
		return visNeighbor{Id: r.name, NeighborCount: routerNeighborCount(r, home, roleInAreas)}
	}

	seenAreas := make(map[*area]bool)
	// Keep router neighbors first, preserving the existing output order.
	for _, in := range net.interfaces {
		node.Neighbors = append(node.Neighbors, getVisNeigh(in))
	}
	for _, in := range net.interfaces {
		// Add neighboring areas at this network's boundary interfaces,
		// excluding its own area and enclosing areas.
		for _, a := range roleInAreas[in] {
			if seenAreas[a] || a == net.zone.inArea || areaIsAncestor(net.zone.inArea, a) {
				continue
			}
			seenAreas[a] = true
			node.Neighbors = append(node.Neighbors,
				visNeighbor{Id: a.name, NeighborCount: areaCount[a]})
		}
	}
	for _, h := range net.hosts {
		node.Hosts = append(node.Hosts, h.name)
	}
	networks[net.name] = node
}

func getVisRouter(r *router, home map[*router]*area, roleInAreas map[*routerIntf][]*area, areaCount map[*area]int, routers map[string]visRouter) {
	var node visRouter
	node.Id = r.name

	var intfs intfList
	getIntfs := func(r *router) intfList {
		intfs = r.origIntfs
		if intfs == nil {
			intfs = r.interfaces
		}
		return intfs
	}
	intfs = getIntfs(r)

	routerArea := home[r]

	var typ = "router"
	if r.managed == "" {
		if r.routingOnly {
			typ += ": routing_only"
		}
	} else {
		typ += ": " + r.managed
	}

	node.Type = typ

	seen := make(map[string]bool)

	addNeighbors := func(intf *routerIntf, ignoreCombined bool) {
		if !(ignoreCombined && intf.isCombined46()) {
			if intf.network.ipType == tunnelIP {
				for _, intf2 := range intf.network.interfaces {
					if intf2.router != r {
						node.Neighbors = append(node.Neighbors,
							visNeighbor{Id: intf2.router.name, NeighborCount: len(intf2.router.interfaces), IsTunnel: true})
					}
				}
			} else {
				node.Neighbors = append(node.Neighbors,
					visNeighbor{Id: intf.network.name, NeighborCount: networkNeighborCount(intf.network, roleInAreas)})
				// Add neighboring area, but not the area the router belongs to
				// and not an enclosing area.
				addArea := func(a *area) {
					if a != nil && a != routerArea && !areaIsAncestor(routerArea, a) &&
						!seen[a.name] && r.managed != "" {
						node.Neighbors = append(node.Neighbors,
							visNeighbor{Id: a.name, NeighborCount: areaCount[a]})
						seen[a.name] = true
					}
				}
				addArea(intf.network.zone.inArea)
				// Add areas the interface is a border of.
				for _, a := range roleInAreas[intf] {
					addArea(a)
				}
			}
		}
	}

	for _, intf := range intfs {
		addNeighbors(intf, false)
	}

	if r.isCombined46() {
		for _, intf := range getIntfs(r.combined46) {
			addNeighbors(intf, true)
		}
	}

	if routerArea != nil {
		node.InArea = routerArea.name
	}
	routers[r.name] = node
}
