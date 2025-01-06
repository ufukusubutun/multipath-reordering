::: {.cell .markdown}
### Define configuration for this experiment (example)
:::

::: {.cell .code}
```python
slice_name="mp-" + fablib.get_bastion_username()

node_conf = [
 {'name': "client",  'cores': 4, 'ram': 8, 'disk': 30, 'image': 'default_ubuntu_20', 'packages': ["moreutils"]}, 
 {'name': "router",  'cores': 4, 'ram': 8, 'disk': 30, 'image': 'default_ubuntu_20', 'packages': ["moreutils"]}, 
 {'name': "aggr",    'cores': 4, 'ram': 8, 'disk': 30, 'image': 'default_ubuntu_20', 'packages': ["moreutils"]}, 
 {'name': "server",  'cores': 4, 'ram': 8, 'disk': 30, 'image': 'default_ubuntu_20', 'packages': ["moreutils"]}
]
net_conf = [
 {"name": "net0", "subnet": "10.10.0.0/24", "nodes": [{"name": "client",  "addr": "10.10.0.100"}, {"name": "router",  "addr": "10.10.0.1"}]},
 {"name": "net1", "subnet": "10.10.2.0/23", "nodes": [{"name": "router",  "addr": "10.10.2.1"},   {"name": "aggr",    "addr": "10.10.2.2"}]},
 {"name": "net2", "subnet": "10.10.2.0/23", "nodes": [{"name": "router",  "addr": "10.10.3.1"},   {"name": "aggr",    "addr": "10.10.3.2"}]},
 {"name": "net3", "subnet": "10.10.4.0/24", "nodes": [{"name": "server",  "addr": "10.10.4.100"},  {"name": "aggr",   "addr": "10.10.4.1"}]}
]

route_conf = [
 {"addr": "10.10.4.0/24", "gw": "10.10.0.1", "nodes": ["client"]},
 {"addr": "10.10.0.0/24", "gw": "10.10.4.1", "nodes": ["server"]}

]
exp_conf = {'cores': sum([ n['cores'] for n in node_conf]), 'nic': sum([len(n['nodes']) for n in net_conf]) }
```
:::
