# <a id="intro"/> LUBE #

* [Introduction][intro]
* [Client][client]
	* [Callbacks][clientcb]
	* [Client Implementations][clientimpl]
* [Server][server]
	* [Client IDs][clientid]
	* [Callbacks][servercb]
	* [Server Implementations][serverimpl]

LUBE has recently switched to being class based, and to do that while still providing the users with freedom, it uses [Class Commons][classcommons].
This means that to use LUBE, you will need to use a [Class Commons][classcommons]-compatible class library.

This document uses a generic class syntax like defined below:

	Class() -- instantiate class 'Class'
	mySubClass = subclass(Class) -- create 'mySubClass' as a subclass of 'Class'

## <a id="client"/> Client ##

The client class, lube.Client, defines the following set of functions (or expects its implementations to implement them).
'client' is assumed to be an instance of a lube.Client implementation according to:

	protocolClient = subclass(lube.Client)
	protocolClient._implemented = true
	-- define protocolClient
	client = protocolClient()

* *client:setPing(enabled, time, message)*  
	Sets the ping settings for this client.
	* enabled: Whether or not ping messages are used.
	* time: How often to send a ping message.
	* message: What message to send.
* *success, error = client:connect(host, port, dns)*  
	Connect to a server.
	* host: The hostname or ip of the server. (Sadly luasocket is ipv4-only at the time of writing.)
	* port: The port at which the server is running.
	* dns: Whether to resolve the 'host' argument as hostname. (Optional, true by default.)
* *client:disconnect()*  
	Disconnect from the server, if connected.
* *client:send(data)*  
	Send data to the server.
	* data: A string with data to send.
* *data = client:receive()*  
	Receive data from the server.
* *client:update(dt)*  
	Do all time-based stuff, call callbacks etc.
	* dt: Delta time, time passed since the last call.
* *client:createSocket()*  
	**INTERNAL**
* *client:setOption(option, value)*  
	Set an option for this socket.
	* option: One of:
		* "broadcast": Allow connectivity with broadcast addresses, may fail.

### <a id="clientcb"/> Callbacks ###

You can set your callback functions in the callbacks table, there is 1 callback:

* *client.callbacks.recv(data)*  
	When the server sends data.

### <a id="clientimpl"/> Client Implementations ###

At the moment LUBE ships with 2 client implementations (but it can of course be extended by subclassing lube.Client).
These implementations are:

* lube.udpClient: The one for general use, just udp.
* lube.tcpClient: And for those wanting tcp, just tcp.

## <a id="server"/> Server ##

The server class, lube.Server, defines the following set of functions (or expects its implementations to implement them).
'server' is assumed to be an instance of a lube.Server implementation according to:

	protocolServer = subclass(lube.Server)
	protocolServer._implemented = true
	-- define protocolServer
	server = protocolServer()

* *server:setPing(enabled, time, message)*
	Sets the ping settings used on this server.
	* enabled: Whether or not ping is checked.
	* time: When to time out clients (3x the client time seems to work well).
	* message: What message clients send.
* *server:listen(port)*  
	Start listening, allows people to connect.
	* port: The port to start listening on.
* *server:update(dt)*  
	Do all time-based stuff, call callbacks etc.
	* dt: Delta time, time passed since the last call.
* *server:send(data, clientid)*  
	Send data to a/all client(s).
	* data: The data to send.
	* clientid: The clientid as given by one of the callbacks or receive. Nil/omitted means everyone.
* *data, clientid = server:receive()*  
	Get data from a (random) client.
	* data: The data sent by the client.
	* clientid: The id associated to the client (see the [Client IDs][clientid] section).
* *server:accept()*  
	**INTERNAL**
* *server:createSocket()*  
	**INTERNAL**

### <a id="clientid"/> Client IDs ###

Client IDs are implementation defined, and they should just be passed along without the code caring what it is.
However, for those interested, udp currently uses the client's ip and port (in ip:port format), and tcp uses the socket object.  
Once again, **do not**, *do not* use this info if you want stable code.  

A client id is defined as nothing more but what the implementation can use to identify a client.

### <a id="servercb"/> Callbacks ###

You can set your callback functions in the callbacks table, there are 3 callbacks:

* *server.callbacks.recv(data, clientid)*  
	When a client sends data.
* *server.callbacks.connect(clientid)*  
	When a client connects.
* *server.callbacks.disconnect(clientid)*  
	When a client disconnects.
  
### <a id="serverimpl"/> Server Implementations ###

LUBE ships with 2 server implementations (more can of course be added).
These are:

* lube.udpServer: The normal one, matches udpClient, just udp.
* lube.tcpServer: And the tcp version, matches tcpClient, just tcp.

[intro]: #intro
[client]: #client
[clientcb]: #clientcb
[clientimpl]: #clientimpl
[server]: #server
[clientid]: #clientid
[servercb]: #servercb
[serverimpl]: #serverimpl

[classcommons]: https://github.com/bartbes/Class-Commons
