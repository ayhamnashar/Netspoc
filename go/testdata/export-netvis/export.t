############################################################
=TITLE=Option '-h'
=INPUT=#
=PARAMS=-h
=ERROR=
Usage: PROGRAM [options] FILE|DIR
  -q, --quiet   Don't print progress messages
=END=

############################################################
=TITLE=Unknown option
=INPUT=#
=PARAMS=--abc
=ERROR=
Error: unknown flag: --abc
=END=

############################################################
=TITLE=No input file
=INPUT=NONE
=ERROR=
Usage: PROGRAM [options] FILE|DIR
  -q, --quiet   Don't print progress messages
=END=

############################################################
=TITLE=Invalid input
=INPUT=
foo
=ERROR=
Error: Typed name expected at line 1 of INPUT, near "--HERE-->foo"
Aborted
=END=

############################################################
=TITLE=Empty input
=INPUT=

=WARNING=
Warning: Ignoring file 'INPUT' without any content
=OUTPUT=
{"area":{},"network":{},"router":{}}
=END=

############################################################
=TITLE=One Network One Managed Router
=INPUT=
network:n1 = {
 ip = 10.1.1.0/24;
 host:h1 = { ip = 10.1.1.5; }
}
router:r1 = {
 managed;
 model = ASA;
 interface:n1 = { ip = 10.1.1.1; hardware = n1; }
}
=OUTPUT=
{
 "area": {},
 "network": {
  "network:n1":  {
   "address": "10.1.1.0/24", "hosts": ["host:h1"],
   "id": "network:n1", "neighbors": [{"id":"router:r1","neighbor_count":1}],
   "type": "network"
  }
 },
 "router": {
  "router:r1": {
   "id":"router:r1", "neighbors": [{"id":"network:n1","neighbor_count":1}],
   "type": "router: standard"
  }
 }
}
=END=

############################################################
=TITLE=One Network One Router in One Area
=INPUT=
network:n1 = {
 ip = 10.1.1.0/24;
 host:h1 = { ip = 10.1.1.5; }
}
router:r1 = {
 interface:n1 = { ip = 10.1.1.1; }
}
area:a1 = {
 anchor = network:n1;
}
=OUTPUT=
{
 "area": {
  "area:a1": {
   "id": "area:a1",
   "networks": ["network:n1"],
   "routers": ["router:r1"],
   "type": "area"
  }
 },
 "network": {
  "network:n1":  {
   "address": "10.1.1.0/24", "hosts": ["host:h1"],
   "id": "network:n1", "in_area": "area:a1",
   "neighbors": [{"id":"router:r1","neighbor_count":1}], "type": "network"
  }
 },
 "router": {
  "router:r1": {
   "id":"router:r1", "in_area": "area:a1",
   "neighbors": [{"id":"network:n1","neighbor_count":1}], "type": "router"
  }
 }
}
=END=

############################################################
=TITLE=Tunnelconnection
=INPUT=
ipsec:aes256SHA = {
 key_exchange = isakmp:aes256SHA; esp_encryption = aes256;
 esp_authentication = sha; pfs_group = 2; lifetime = 600 sec;
}
isakmp:aes256SHA = {
 authentication = rsasig; encryption = aes256;
 hash = sha; group = 2; lifetime = 86400 sec;
}
crypto:vpn = {type = ipsec:aes256SHA;}
router:asavpn = {
 model = ASA, VPN;
 managed;
 general_permit = icmp 3;
 vpn_attributes = {
  trust-point = ASDM_TrustPoint1;
 }
 interface:dmz = {
  ip = 192.168.0.101;
  hub = crypto:vpn;
  hardware = outside;
 }
}
network:dmz = { ip = 192.168.0.0/24; }
router:extern = {
 interface:dmz = { ip = 192.168.0.1; }
 interface:internet;
}
network:internet = {
 ip = 0.0.0.0/0;
 has_subnets;
}
router:softclients = {
 interface:internet = {
  spoke = crypto:vpn;
 }
}
=OUTPUT=
{
 "area": {},
 "network": {"network:dmz":{"id":"network:dmz","type":"network","address":"192.168.0.0/24","neighbors":[{"id":"router:asavpn","neighbor_count":1},{"id":"router:extern","neighbor_count":2}],"hosts":null},"network:internet":{"id":"network:internet","type":"network","address":"0.0.0.0/0","neighbors":[{"id":"router:extern","neighbor_count":2},{"id":"router:softclients","neighbor_count":1}],"hosts":null}},
 "router": {
    "router:asavpn": {
      "id": "router:asavpn",
      "type": "router: standard",
            "neighbors": [
        {
          "id": "network:dmz",
          "neighbor_count": 2
        },
        {
          "id": "router:softclients",
          "neighbor_count": 1,
          "is_tunnel": true
        }
      ]
    },
    "router:extern": {"id":"router:extern","type":"router","neighbors":[{"id":"network:dmz","neighbor_count":2},{"id":"network:internet","neighbor_count":2}]},
    "router:softclients": {
      "id": "router:softclients",
      "type": "router",
            "neighbors": [
        {
          "id": "network:internet",
          "neighbor_count": 2
        },
        {
          "id": "router:asavpn",
          "neighbor_count": 1,
          "is_tunnel": true
        }
      ]
    }
  }
 }
=END=

############################################################
=TITLE=One Router Two Areas
=INPUT=
router:r1 = {
 managed;
 model = ASA;
 interface:n1 = { ip = 10.1.1.1; hardware = n1; }
 interface:n2 = { ip = 10.1.2.1; hardware = n2; }
}

network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }

area:a1 = {
 border = interface:r1.n1;
}

area:a2 = {
 border = interface:r1.n2;
}
=OUTPUT=
{
  "area": {
    "area:a1": {
      "border": [
        "interface:r1.n1"
      ],
      "id": "area:a1",
      "neighbors": [
        "router:r1"
      ],
      "networks": [
        "network:n1"
      ],
      "routers": null,
      "type": "area"
    },
    "area:a2": {
      "border": [
        "interface:r1.n2"
      ],
      "id": "area:a2",
      "neighbors": [
        "router:r1"
      ],
      "networks": [
        "network:n2"
      ],
      "routers": null,
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:a1",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 4
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:a2",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 4
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 1
        },
        {
          "id": "area:a1",
          "neighbor_count": 1
        },
        {
          "id": "network:n2",
          "neighbor_count": 1
        },
        {
          "id": "area:a2",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    }
  }
}
=END=

############################################################
=TITLE=One Router routing only
=INPUT=
router:r1 = {
 managed = routing_only;
 model = ASA;
 interface:n1 = { ip = 10.1.1.1; hardware = n1; }
}
network:n1 = { ip = 10.1.1.0/24; }
=OUTPUT=
{
  "area": {},
  "network": {
    "network:n1": {
      "id": "network:n1",
      "type": "network",
            "address": "10.1.1.0/24",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 1
        }
      ],
      "hosts": null
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "type": "router: routing_only",
            "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 1
        }
      ]
    }
  }
}
=END=

############################################################
=TITLE=One Dualstack Network One Managed Router
=INPUT=
network:n1 = {
 ip = 10.1.1.0/24;
 ip6 = 2001:0db8:1::/64;
 host:h1 = { ip = 10.1.1.5; }
}
router:r1 = {
 managed;
 model = ASA;
 interface:n1 = { ip = 10.1.1.1; hardware = n1; }
}
=OUTPUT=
{
 "area": {},
 "network": {
  "network:n1":  {
   "address": "10.1.1.0/24",
   "address2": "2001:db8:1::/64",
   "hosts": ["host:h1"],
   "id": "network:n1", "neighbors": [{"id":"router:r1","neighbor_count":1}],
   "type": "network"
  }
 },
 "router": {
  "router:r1": {
   "id":"router:r1", "neighbors": [{"id":"network:n1","neighbor_count":1}],
   "type": "router: standard"
  }
 }
}
=END=

############################################################
=TITLE=Dualstack Router with one v4 and one v6 Interface
=INPUT=
network:v4       = { ip = 10.1.1.0/24; }
network:v6       = { ip6 = 2001:db8:1::/64; }
network:combined = { ip = 10.1.2.0/24; ip6 = 2001:db8:2::/64; }
router:r1 = {
 managed;
 model = ASA;
 interface:v4       = { ip = 10.1.1.1; hardware = inside; }
 interface:v6       = { ip6 = 2001:db8:1::1; hardware = inside; }
 interface:combined = { ip = 10.1.2.1; ip6 = 2001:db8:2::1; hardware = outside; }
}

=OUTPUT=
{
  "area": {},
  "network": {
    "network:combined": {
      "id": "network:combined",
      "type": "network",
      "address": "10.1.2.0/24",
      "address2": "2001:db8:2::/64",
      "neighbors": [{"id":"router:r1","neighbor_count": 2}],
      "hosts": null
    },
    "network:v4": {
      "id": "network:v4",
      "type": "network",
      "address": "10.1.1.0/24",
      "neighbors": [{"id":"router:r1","neighbor_count": 2}],
      "hosts": null
    },
    "network:v6": {
      "id": "network:v6",
      "type": "network",
      "address": "2001:db8:1::/64",
      "neighbors": [{"id":"router:r1","neighbor_count": 2}],
      "hosts": null
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "type": "router: standard",
      "neighbors": [{"id":"network:v4","neighbor_count": 1},{"id":"network:combined","neighbor_count": 1},{"id":"network:v6","neighbor_count": 1}]
    }
  }
}
=END=

############################################################
=TITLE=Nested Areas with Neighbor Detection
=INPUT=

network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }
network:n4 = { ip = 10.1.4.0/24; }
network:n5 = { ip = 10.1.5.0/24; }
network:n6 = { ip = 10.1.6.0/24; }

router:r1 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.1; hardware = n1; }
    interface:n2 = { ip = 10.1.2.1; hardware = n2; }
    interface:n3 = { ip = 10.1.3.1; hardware = n3; }
}

router:r2 = {
    managed;
    model = ASA;
    interface:n2 = { ip = 10.1.2.2; hardware = n2; }
}

router:r3 = {
    managed;
    model = ASA;
    interface:n3 = { ip = 10.1.3.3; hardware = n3; }
    interface:n4 = { ip = 10.1.4.3; hardware = n4; }
}

router:r4 = {
    managed;
    model = ASA;
    interface:n4 = { ip = 10.1.4.4; hardware = n4; }
}

router:r5 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.5; hardware = n1; }
    interface:n5 = { ip = 10.1.5.4; hardware = n5; }
}

router:r6 = {
    managed;
    model = ASA;
    interface:n5 = { ip = 10.1.5.6; hardware = n5; }
    interface:n6 = { ip = 10.1.6.6; hardware = n6; }
}


area:all = {
    anchor = network:n1;
}

area:b = {
    inclusive_border = interface:r1.n1;
}

area:a = {
    inclusive_border = interface:r1.n1;
    border = interface:r3.n3;
}

area:c = {
    inclusive_border = interface:r5.n1;
}

=OUTPUT=
{
  "area": {
    "area:a": {
      "border": [
        "interface:r3.n3"
      ],
      "id": "area:a",
      "in_area": "area:b",
      "inclusive_border": [
        "interface:r1.n1"
      ],
      "neighbors": [
        "network:n1",
        "router:r3"
      ],
      "networks": [
        "network:n2",
        "network:n3"
      ],
      "routers": [
        "router:r1",
        "router:r2"
      ],
      "type": "area"
    },
    "area:all": {
      "child_areas": [
        "area:b",
        "area:c"
      ],
      "id": "area:all",
      "networks": [
        "network:n1"
      ],
      "routers": null,
      "type": "area"
    },
    "area:b": {
      "child_areas": [
        "area:a"
      ],
      "id": "area:b",
      "in_area": "area:all",
      "inclusive_border": [
        "interface:r1.n1"
      ],
      "neighbors": [
        "network:n1"
      ],
      "networks": [
        "network:n4"
      ],
      "routers": [
        "router:r3",
        "router:r4"
      ],
      "type": "area"
    },
    "area:c": {
      "id": "area:c",
      "in_area": "area:all",
      "inclusive_border": [
        "interface:r5.n1"
      ],
      "neighbors": [
        "network:n1"
      ],
      "networks": [
        "network:n5",
        "network:n6"
      ],
      "routers": [
        "router:r5",
        "router:r6"
      ],
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:all",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        },
        {
          "id": "router:r5",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        },
        {
          "id": "area:b",
          "neighbor_count": 1
        },
        {
          "id": "area:c",
          "neighbor_count": 1
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        },
        {
          "id": "router:r2",
          "neighbor_count": 1
        }
      ],
      "type": "network"
    },
    "network:n3": {
      "address": "10.1.3.0/24",
      "hosts": null,
      "id": "network:n3",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        },
        {
          "id": "router:r3",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n4": {
      "address": "10.1.4.0/24",
      "hosts": null,
      "id": "network:n4",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "router:r3",
          "neighbor_count": 3
        },
        {
          "id": "router:r4",
          "neighbor_count": 1
        }
      ],
      "type": "network"
    },
    "network:n5": {
      "address": "10.1.5.0/24",
      "hosts": null,
      "id": "network:n5",
      "in_area": "area:c",
      "neighbors": [
        {
          "id": "router:r5",
          "neighbor_count": 2
        },
        {
          "id": "router:r6",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n6": {
      "address": "10.1.6.0/24",
      "hosts": null,
      "id": "network:n6",
      "in_area": "area:c",
      "neighbors": [
        {
          "id": "router:r6",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 5
        },
        {
          "id": "network:n2",
          "neighbor_count": 2
        },
        {
          "id": "network:n3",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r2": {
      "id": "router:r2",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n2",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r3": {
      "id": "router:r3",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "network:n3",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        },
        {
          "id": "network:n4",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r4": {
      "id": "router:r4",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "network:n4",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r5": {
      "id": "router:r5",
      "in_area": "area:c",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 5
        },
        {
          "id": "network:n5",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r6": {
      "id": "router:r6",
      "in_area": "area:c",
      "neighbors": [
        {
          "id": "network:n5",
          "neighbor_count": 2
        },
        {
          "id": "network:n6",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    }
  }
}
=END=

############################################################
=TITLE=Same Interface as Inclusive Border and Border
=INPUT=

network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }

router:r1 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.1; hardware = n1; }
    interface:n2 = { ip = 10.1.2.1; hardware = n2; }
}

router:r2 = {
    interface:n2 = { ip = 10.1.2.2; }
    interface:n3 = { ip = 10.1.3.1; }
}

area:a = {
    inclusive_border = interface:r1.n2;
}

area:b = {
    border = interface:r1.n2;
}

=OUTPUT=
{
  "area": {
    "area:a": {
      "id": "area:a",
      "inclusive_border": [
        "interface:r1.n2"
      ],
      "neighbors": [
        "area:b",
        "network:n2"
      ],
      "networks": [
        "network:n1"
      ],
      "routers": [
        "router:r1"
      ],
      "type": "area"
    },
    "area:b": {
      "border": [
        "interface:r1.n2"
      ],
      "id": "area:b",
      "neighbors": [
        "area:a",
        "router:r1"
      ],
      "networks": [
        "network:n2",
        "network:n3"
      ],
      "routers": [
        "router:r2"
      ],
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        },
        {
          "id": "router:r2",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n3": {
      "address": "10.1.3.0/24",
      "hosts": null,
      "id": "network:n3",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "router:r2",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 1
        },
        {
          "id": "network:n2",
          "neighbor_count": 3
        },
        {
          "id": "area:b",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r2": {
      "id": "router:r2",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "network:n2",
          "neighbor_count": 3
        },
        {
          "id": "network:n3",
          "neighbor_count": 1
        }
      ],
      "type": "router"
    }
  }
}
=END=

############################################################
=TITLE=Nested Areas with Border Router in Parent
=INPUT=
network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }
network:n4 = { ip = 10.1.4.0/24; }

router:r1 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.1; hardware = n1; }
    interface:n2 = { ip = 10.1.2.1; hardware = n2; }
}

router:r2 = {
    managed;
    model = ASA;
    interface:n2 = { ip = 10.1.2.2; hardware = n2; }
    interface:n3 = { ip = 10.1.3.1; hardware = n3; }
}

router:r3 = {
    managed;
    model = ASA;
    interface:n3 = { ip = 10.1.3.3; hardware = n3; }
    interface:n4 = { ip = 10.1.4.3; hardware = n4; }
}

area:large = {
    anchor = network:n1;
}

area:small = {
    border = interface:r2.n3;
}

=OUTPUT=
{
  "area": {
    "area:large": {
      "child_areas": [
        "area:small"
      ],
      "id": "area:large",
      "networks": [
        "network:n1",
        "network:n2"
      ],
      "routers": [
        "router:r1",
        "router:r2"
      ],
      "type": "area"
    },
    "area:small": {
      "border": [
        "interface:r2.n3"
      ],
      "id": "area:small",
      "in_area": "area:large",
      "neighbors": [
        "router:r2"
      ],
      "networks": [
        "network:n3",
        "network:n4"
      ],
      "routers": [
        "router:r3"
      ],
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:large",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:large",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 2
        },
        {
          "id": "router:r2",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n3": {
      "address": "10.1.3.0/24",
      "hosts": null,
      "id": "network:n3",
      "in_area": "area:small",
      "neighbors": [
        {
          "id": "router:r2",
          "neighbor_count": 3
        },
        {
          "id": "router:r3",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n4": {
      "address": "10.1.4.0/24",
      "hosts": null,
      "id": "network:n4",
      "in_area": "area:small",
      "neighbors": [
        {
          "id": "router:r3",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "in_area": "area:large",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 1
        },
        {
          "id": "network:n2",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r2": {
      "id": "router:r2",
      "in_area": "area:large",
      "neighbors": [
        {
          "id": "network:n2",
          "neighbor_count": 2
        },
        {
          "id": "network:n3",
          "neighbor_count": 2
        },
        {
          "id": "area:small",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    },
    "router:r3": {
      "id": "router:r3",
      "in_area": "area:small",
      "neighbors": [
        {
          "id": "network:n3",
          "neighbor_count": 2
        },
        {
          "id": "network:n4",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    }
  }
}
=END=

############################################################
=TITLE=Three Level Nested Areas
=INPUT=
network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }
network:n4 = { ip = 10.1.4.0/24; }

router:r1 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.1; hardware = n1; }
    interface:n2 = { ip = 10.1.2.1; hardware = n2; }
}

router:r2 = {
    managed;
    model = ASA;
    interface:n2 = { ip = 10.1.2.2; hardware = n2; }
    interface:n3 = { ip = 10.1.3.1; hardware = n3; }
}

router:r3 = {
    managed;
    model = ASA;
    interface:n3 = { ip = 10.1.3.3; hardware = n3; }
    interface:n4 = { ip = 10.1.4.3; hardware = n4; }
}

area:c = {
    anchor = network:n1;
}

area:b = {
    inclusive_border = interface:r1.n1;
}

area:a = {
    inclusive_border = interface:r1.n1;
    border = interface:r3.n3;
}

=OUTPUT=
{
  "area": {
    "area:a": {
      "border": [
        "interface:r3.n3"
      ],
      "id": "area:a",
      "in_area": "area:b",
      "inclusive_border": [
        "interface:r1.n1"
      ],
      "neighbors": [
        "network:n1",
        "router:r3"
      ],
      "networks": [
        "network:n2",
        "network:n3"
      ],
      "routers": [
        "router:r1",
        "router:r2"
      ],
      "type": "area"
    },
    "area:b": {
      "child_areas": [
        "area:a"
      ],
      "id": "area:b",
      "in_area": "area:c",
      "inclusive_border": [
        "interface:r1.n1"
      ],
      "neighbors": [
        "network:n1"
      ],
      "networks": [
        "network:n4"
      ],
      "routers": [
        "router:r3"
      ],
      "type": "area"
    },
    "area:c": {
      "child_areas": [
        "area:b"
      ],
      "id": "area:c",
      "networks": [
        "network:n1"
      ],
      "routers": null,
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:c",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        },
        {
          "id": "area:b",
          "neighbor_count": 1
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 2
        },
        {
          "id": "router:r2",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n3": {
      "address": "10.1.3.0/24",
      "hosts": null,
      "id": "network:n3",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r2",
          "neighbor_count": 2
        },
        {
          "id": "router:r3",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n4": {
      "address": "10.1.4.0/24",
      "hosts": null,
      "id": "network:n4",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "router:r3",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 3
        },
        {
          "id": "network:n2",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r2": {
      "id": "router:r2",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n2",
          "neighbor_count": 2
        },
        {
          "id": "network:n3",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r3": {
      "id": "router:r3",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "network:n3",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        },
        {
          "id": "network:n4",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    }
  }
}
=END=

############################################################
=TITLE=Two Areas Connected Through Shared Network
=INPUT=
network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }

router:r1 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.1; hardware = n1; }
    interface:n2 = { ip = 10.1.2.1; hardware = n2; }
}

router:r2 = {
    managed;
    model = ASA;
    interface:n2 = { ip = 10.1.2.2; hardware = n2; }
    interface:n3 = { ip = 10.1.3.1; hardware = n3; }
}

area:a = {
    border = interface:r1.n1;
}

area:b = {
    border = interface:r2.n3;
}

=OUTPUT=
{
  "area": {
    "area:a": {
      "border": [
        "interface:r1.n1"
      ],
      "id": "area:a",
      "neighbors": [
        "router:r1"
      ],
      "networks": [
        "network:n1"
      ],
      "routers": null,
      "type": "area"
    },
    "area:b": {
      "border": [
        "interface:r2.n3"
      ],
      "id": "area:b",
      "neighbors": [
        "router:r2"
      ],
      "networks": [
        "network:n3"
      ],
      "routers": null,
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 3
        },
        {
          "id": "router:r2",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n3": {
      "address": "10.1.3.0/24",
      "hosts": null,
      "id": "network:n3",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "router:r2",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 1
        },
        {
          "id": "area:a",
          "neighbor_count": 1
        },
        {
          "id": "network:n2",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r2": {
      "id": "router:r2",
      "neighbors": [
        {
          "id": "network:n2",
          "neighbor_count": 2
        },
        {
          "id": "network:n3",
          "neighbor_count": 1
        },
        {
          "id": "area:b",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    }
  }
}
=END=
############################################################
=TITLE=Two Areas Sharing a Border Router
=INPUT=
network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }
network:n3 = { ip = 10.1.3.0/24; }
network:n4 = { ip = 10.1.4.0/24; }

router:r1 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.1; hardware = n1; }
    interface:n2 = { ip = 10.1.2.1; hardware = n2; }
}

router:r2 = {
    managed;
    model = ASA;
    interface:n1 = { ip = 10.1.1.2; hardware = n1; }
    interface:n3 = { ip = 10.1.3.1; hardware = n3; }
}

router:r3 = {
    managed;
    model = ASA;
    interface:n3 = { ip = 10.1.3.3; hardware = n3; }
    interface:n4 = { ip = 10.1.4.3; hardware = n4; }
}

area:a = {
    border = interface:r1.n1, interface:r3.n3;
}

area:b = {
    border = interface:r1.n2;
}
=OUTPUT=
{
  "area": {
    "area:a": {
      "border": [
        "interface:r1.n1",
        "interface:r3.n3"
      ],
      "id": "area:a",
      "neighbors": [
        "router:r1",
        "router:r3"
      ],
      "networks": [
        "network:n1",
        "network:n3"
      ],
      "routers": [
        "router:r2"
      ],
      "type": "area"
    },
    "area:b": {
      "border": [
        "interface:r1.n2"
      ],
      "id": "area:b",
      "neighbors": [
        "router:r1"
      ],
      "networks": [
        "network:n2"
      ],
      "routers": null,
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 4
        },
        {
          "id": "router:r2",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:b",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 4
        }
      ],
      "type": "network"
    },
    "network:n3": {
      "address": "10.1.3.0/24",
      "hosts": null,
      "id": "network:n3",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r2",
          "neighbor_count": 2
        },
        {
          "id": "router:r3",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    },
    "network:n4": {
      "address": "10.1.4.0/24",
      "hosts": null,
      "id": "network:n4",
      "neighbors": [
        {
          "id": "router:r3",
          "neighbor_count": 3
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        },
        {
          "id": "network:n2",
          "neighbor_count": 1
        },
        {
          "id": "area:b",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    },
    "router:r2": {
      "id": "router:r2",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 2
        },
        {
          "id": "network:n3",
          "neighbor_count": 2
        }
      ],
      "type": "router: standard"
    },
    "router:r3": {
      "id": "router:r3",
      "neighbors": [
        {
          "id": "network:n3",
          "neighbor_count": 2
        },
        {
          "id": "area:a",
          "neighbor_count": 2
        },
        {
          "id": "network:n4",
          "neighbor_count": 1
        }
      ],
      "type": "router: standard"
    }
  }
}
=END=

############################################################
=TITLE=Area with Unmanaged Router
=INPUT=
network:n1 = { ip = 10.1.1.0/24; }
network:n2 = { ip = 10.1.2.0/24; }

router:r1 = {
    interface:n1 = { ip = 10.1.1.1; }
    interface:n2 = { ip = 10.1.2.1; }
}

area:a = {
    anchor = network:n1;
}
=OUTPUT=
{
  "area": {
    "area:a": {
      "id": "area:a",
      "networks": [
        "network:n1",
        "network:n2"
      ],
      "routers": [
        "router:r1"
      ],
      "type": "area"
    }
  },
  "network": {
    "network:n1": {
      "address": "10.1.1.0/24",
      "hosts": null,
      "id": "network:n1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    },
    "network:n2": {
      "address": "10.1.2.0/24",
      "hosts": null,
      "id": "network:n2",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "router:r1",
          "neighbor_count": 2
        }
      ],
      "type": "network"
    }
  },
  "router": {
    "router:r1": {
      "id": "router:r1",
      "in_area": "area:a",
      "neighbors": [
        {
          "id": "network:n1",
          "neighbor_count": 1
        },
        {
          "id": "network:n2",
          "neighbor_count": 1
        }
      ],
      "type": "router"
    }
  }
}
=END=