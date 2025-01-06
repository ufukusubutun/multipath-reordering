
::: {.cell .markdown}
### Configure queues
:::

::: {.cell .code}
```python
# all of the experiment factors. For now, just one value. Later, we make these lists
# and we can systematically run a full factorial experiment.
exp = {
    'link_rate':  130,  # rate of interface at endpoints and router reverse path, in Mbps.
    'link_buf':   2.6,  # size of interface at endpoints and router reverse path, in Mbit.
    'link_delay': 10,   # in ms, applied at aggr only
    'p1_rate':    130,  # rate of router egress interface for path 1, in Mbps 
    'p1_buf':     2.6,  # size of router egress buffer for path 1, in Mbit
    'p1_delay':   0.01, # delay of router egress interface for path 1, in ms 
    'p2_rate':    130,  # rate of router egress interface for path 2, in Mbps 
    'p2_buf':     2.6,  # size of router egress buffer for path 2, in Mbit
    'p2_delay':   0.01, # delay of router egress interface for path 2, in ms 
    'p2_prob':    0.5,  # probability of being marked for path 2 
    'lb_type':    "packet", # can be "packet" or "flow"
    'trial':      1     # trial index
}
```
:::

::: {.cell .code}
```python
client_node = slice.get_node(name="client")
client_iface  = client_node.get_interface(network_name = "net0")
client_ifname = client_iface.get_device_name()

client_tc_cmd = '''
	sudo tc qdisc del dev {iface} root  
	sudo tc qdisc add dev {iface} root handle 1: htb default 3  
	sudo tc class add dev {iface} parent 1:2 classid 1:3 htb rate {rate}Mbit  
	sudo tc qdisc add dev {iface} parent 1:3 bfifo limit  {buf}mbit 
    '''.format(iface=client_ifname, rate=exp['link_rate'], buf=exp['link_buf'])

client_node.execute(client_tc_cmd)

```
:::

::: {.cell .code}
```python
router_node = slice.get_node(name="router")
router_iface_0  = router_node.get_interface(network_name = "net0")
router_iface_1  = router_node.get_interface(network_name = "net1")
router_iface_2  = router_node.get_interface(network_name = "net2")
router_ifname_0 = router_iface_0.get_device_name()
router_ifname_1 = router_iface_1.get_device_name()
router_ifname_2 = router_iface_2.get_device_name()

router_tc_cmd = '''

	# configure next hop for path via net1
	sudo ip route add 10.10.4.0/24 via 10.10.2.2 dev {iface1}

	sudo tc qdisc del dev {iface1} root  
	sudo tc qdisc add dev {iface1} root handle 1: htb default 3  
	sudo tc class add dev {iface1} parent 1:2 classid 1:3 htb rate {r1}Mbit quantum 1514
	sudo tc qdisc add dev {iface1} parent 1:3 handle 3: netem delay {d1}ms
	sudo tc qdisc add dev {iface1} parent 3: bfifo limit {b1}mbit 


	# configure next hop for path via net2
	sudo ip route add 10.10.4.0/24 via 10.10.3.2 dev {iface2} table 100
	sudo ip rule add fwmark 3 table 100 

	sudo tc qdisc del dev {iface2} root  
	sudo tc qdisc add dev {iface2} root handle 1: htb default 3  
	sudo tc class add dev {iface2} parent 1:2 classid 1:3 htb rate {r2}Mbit quantum 1514 
	sudo tc qdisc add dev {iface2} parent 1:3 handle 3: netem delay {d2}ms
	sudo tc qdisc add dev {iface2} parent 3: bfifo limit {b2}mbit 


	# configure reverse path
	sudo tc qdisc del dev {iface0} root  
	sudo tc qdisc add dev {iface0} root handle 1: htb default 3  
	sudo tc class add dev {iface0}parent 1:2 classid 1:3 htb rate {rl}Mbit  
	sudo tc qdisc add dev {iface0} parent 1:3 bfifo limit  {bl}mbit 

    '''.format(iface0=router_ifname_0, iface1=router_ifname_1, iface2=router_ifname_2, 
    		r1=exp['p1_rate'],   b1=exp['p1_buf'], d1=exp['p1_delay'], 
    		r2=exp['p2_rate'],   b2=exp['p2_buf'], d2=exp['p2_delay'],
    		rl=exp['link_rate'], bl=exp['link_buf'])
    
router_node.execute(router_tc_cmd)
```
:::

::: {.cell .code}
```python
if exp['lb_type']=="packet":
	router_iptables_cmd = '''
		# flush first!
		sudo iptables -t mangle -F
		sudo iptables -A PREROUTING -m statistic --mode nth --every {n_packets} --packet 0 -t mangle --destination 10.10.4.100/24 --source 10.10.0.100/1 -j MARK --set-mark 3
		sudo iptables -A PREROUTING -m mark --mark 3 -t mangle -j RETURN
	'''

	
if exp['lb_type']=="flow":

	router_iptables_cmd = '''
		# flush first!
		sudo iptables -t mangle -F
		# Mark all flows to 2
		sudo iptables -t mangle -A PREROUTING -i {iface0} -m conntrack --ctstate NEW -j CONNMARK --set-mark 2
		# Mark half of the flows to 1
		sudo iptables -t mangle -A PREROUTING -i {iface0} -m conntrack --ctstate NEW -m statistic --mode random --probability {prob} -j CONNMARK --set-mark 1
		# restore and overwrite (?) the mark of previously marked flows
		sudo iptables -t mangle -A PREROUTING -i {iface0} -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

		# Mark packets 3 if they belong to flows marked 1
		sudo iptables -t mangle -A PREROUTING -m connmark --mark 1 -j MARK --set-mark 3
		# if a packet is marked with 3 return
		sudo iptables -A PREROUTING -m mark --mark 3 -t mangle -j RETURN

		# not used in this example - you can mark more packets with different marks as follows 
		#sudo iptables -t mangle -A PREROUTING -m connmark --mark 2 -j MARK --set-mark 4
		#sudo iptables -A PREROUTING -m mark --mark 4 -t mangle -j RETURN
	'''.format(iface0=router_ifname_0, prob=exp['p2_prob'], n_packets=int(1/exp['p2_prob']))

	
router_node.execute(router_iptables_cmd)
```
:::

::: {.cell .code}
```python
router_node.execute("sudo iptables -L -n -t mangle")
```
:::


::: {.cell .code}
```python
aggr_node = slice.get_node(name="aggr")
aggr_iface_3  = aggr_node.get_interface(network_name = "net3")
aggr_iface_1  = aggr_node.get_interface(network_name = "net1")
aggr_iface_2  = aggr_node.get_interface(network_name = "net2")
aggr_ifname_3 = aggr_iface_3.get_device_name()
aggr_ifname_1 = aggr_iface_1.get_device_name()
aggr_ifname_2 = aggr_iface_2.get_device_name()

aggr_tc_cmd = '''

	# configure next hop for path via net1
	sudo ip route add 10.10.0.0/24 via 10.10.2.1 dev {iface1}

	sudo tc qdisc del dev {iface1} root  
	sudo tc qdisc add dev {iface1} root handle 1: htb default 3  
	sudo tc class add dev {iface1} parent 1:2 classid 1:3 htb rate {r1}Mbit quantum 1514
	sudo tc qdisc add dev {iface1} parent 1:3 bfifo limit {b1}mbit 	


	# configure next hop for path via net2
	sudo ip route add 10.10.0.0/24 via 10.10.3.1 dev {iface2} table 100
	sudo ip rule add fwmark 3 table 100 

	sudo tc qdisc del dev {iface2} root  
	sudo tc qdisc add dev {iface2} root handle 1: htb default 3  
	sudo tc class add dev {iface2} parent 1:2 classid 1:3 htb rate {r2}Mbit quantum 1514 
	sudo tc qdisc add dev {iface2} parent 1:3 handle 3: netem delay {d2}ms
	sudo tc qdisc add dev {iface2} parent 1:3 bfifo limit {b2}mbit 	


	# configure path to server

	sudo tc qdisc del dev {iface3} root  
	sudo tc qdisc add dev {iface3} root handle 1: htb default 3  
	sudo tc class add dev {iface3} parent 1:2 classid 1:3 htb rate {rl}Mbit quantum 1514 
	sudo tc qdisc add dev {iface3} parent 1:3 handle 3: netem delay {dl}ms
	sudo tc qdisc add dev {iface3} parent 3: bfifo limit {bl}mbit 
	
	
    '''.format(iface3=aggr_ifname_3, iface1=aggr_ifname_1, iface2=aggr_ifname_2, 
    		r1=exp['p1_rate'],   b1=exp['p1_buf'],   d1=exp['p1_delay'], 
    		r2=exp['p2_rate'],   b2=exp['p2_buf'],   d2=exp['p2_delay'],
    		rl=exp['link_rate'], bl=exp['link_buf'], dl=exp['link_delay'])
    		
aggr_node.execute(aggr_tc_cmd)
```
:::


::: {.cell .code}
```python
server_node = slice.get_node(name="server")
server_iface  = server_node.get_interface(network_name = "net3")
server_ifname = server_iface.get_device_name()

server_tc_cmd = '''
	sudo tc qdisc del dev {iface} root  
	sudo tc qdisc add dev {iface} root handle 1: htb default 3  
	sudo tc class add dev {iface} parent 1:2 classid 1:3 htb rate {rate}Mbit  
	sudo tc qdisc add dev {iface} parent 1:3 bfifo limit  {buf}mbit 
    '''.format(iface=server_ifname, rate=exp['lr'], buf=exp['lb'])


server_node.execute(server_tc_cmd)
```
:::


