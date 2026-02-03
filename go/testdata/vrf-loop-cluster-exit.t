
############################################################
=TITLE=VRF loop cluster - infinite loop without fix
=INPUT=
# This test reproduces the infinite loop bug in VRF loop clusters.
# The bug occurs when:
# 1. A loop exists within a VRF context (created by 2+ networks)
# 2. The loop exit has a self-referencing structure (loop.exit.getLoop() == loop)
# 3. Path calculation navigates through this loop cluster
#
# The fix prevents infinite iteration in path-walk.go's clusterNavigation()
# by detecting when loop.exit.getLoop() == loop and breaking the iteration.

network:n1 = { ip = 10.1.1.0/24; }

# VRF v1 with a LOOP created by two transport networks
router:R@v1 = {
 managed;
 model = IOS;
 interface:n1 = { ip = 10.1.1.1; hardware = e0; }
 interface:trans1 = { ip = 10.9.1.1; hardware = e1; }
 interface:trans2 = { ip = 10.9.2.1; hardware = e2; }
}

# Two transport networks creating a loop
network:trans1 = { ip = 10.9.1.0/24; }
network:trans2 = { ip = 10.9.2.0/24; }

# Firewall in VRF v1 - completes the loop
router:FW@v1 = {
 managed;
 model = IOS;
 interface:trans1 = { ip = 10.9.1.2; hardware = t1; }
 interface:trans2 = { ip = 10.9.2.2; hardware = t2; }
 interface:shared = { ip = 10.8.8.1; hardware = shared; }
}

# Shared network connects to VRF v2
network:shared = { ip = 10.8.8.0/24; }

# VRF v2 on same physical router R
router:R@v2 = {
 managed;
 model = IOS;
 interface:shared = { ip = 10.8.8.2; hardware = e3; }
 interface:n2 = { ip = 10.2.2.1; hardware = e4; }
}

network:n2 = { ip = 10.2.2.0/24; }

# Service crossing VRF boundary through the loop
service:test = {
 user = network:n1;
 permit src = user; dst = network:n2; prt = tcp 80;
}
=ERROR=
Error: Two static routes for network:n1
 via interface:FW@v1.trans2 and interface:FW@v1.trans1
Error: Two static routes for network:n2
 via interface:R@v1.trans2 and interface:R@v1.trans1
=END=

