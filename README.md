# Description #

This cookbook configures Airbnb's SmartStack.
SmartStack is our service registration, discovery and monitoring platform.
It allows you to quickly and reliably connect to other services that you need, and for others to connect to your service.

# Getting started with this cookbook #

This cookbook contains everything you need to get SmartStack up and running, both in development and in production.

## Production Use ##

### Set up zookeeper ###

If you are ready to install SmartStack on your machines, you will first need to do a bit of prep.
First, you will need [Zookeeper](https://cwiki.apache.org/confluence/display/ZOOKEEPER/ProjectDescription) running in your infrastructure.
We recommend using an [existing cookbook](https://github.com/SimpleFinance/chef-zookeeper).
For now, you can just set up a single machine, but for production use we recommend an [ensemble](http://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html#sc_zkMulitServerSetup) of at least 3 nodes managed with [exhibitor](https://github.com/Netflix/exhibitor/wiki).

### Configure chef ###

In your role, environment file, or infrastructure repo:

* set `node.zookeeper.smartstack_cluster` to a list of the zookeeper machines you'll be using for smartstack.
* create a services hash in `smartstack/attributes/services.rb` and `ports.rb` describing how you want your services configured. more information is [below](#configuring-smartstack)
* enable the services you want:
  * where the service is running, add it to `node.nerve.enabled_services`
  * where it is being consumed, add it to `node.synapse.enabled_services`

That's all!
See the more extensive documentation below if you need additional help.

## Dev and Testing ##

This cookbook is configured to be easy to run in dev using [vagrant](http://www.vagrantup.com/).
To get started:

* Install [Virtualbox](https://www.virtualbox.org/wiki/Downloads); it's free!
* Install [Vagrant](http://downloads.vagrantup.com/); this cookbook has been tested with v1.3.5
* Install the [berkshelf](http://berkshelf.com/) plugin for vagrant: `vagrant plugin install vagrant-berkshelf`
* Bring up SmartStack in a VM: `vagrant up`

This will bring up an Ubuntu VM configured with Zookeeper, SmartStack, and a few sample services.
The SmartStack integration tests will automatically run inside the Vagrant VM.

# How SmartStack Works #

## Synapse ##

[Synapse](https://github.com/airbnb/synapse) is a service discovery platform.
It lets you reliably connect to an available worker for a given service.
You don't have to worry about discovery within your application, and you can easily do the same thing in dev as in prod.

### How to use synapse ###

Using synapse to talk to a service is easy.
Just specify that you would like to do so in your role file.
You'll need to add a `'synapse' => {'enabled_services' => ['desired_service']}` section to your `default_attributes` section:

```ruby
name 'myrole'
description 'my role file'

default_attributes({
  'synapse' => { 'enabled_services' => [ 'service1', 'service2' ] }
})

run_list(
  'recipe[smartstack]',
  'recipe[myrole]'
)
```
 
Once you've done this and reconverged your boxes, the service will be available to you on `localhost` at it's synapse port.
If you are writing out a config file in chef and need to specify the port to use, just use `node.smartstack.services.desired_service.local_port` in your config.
You can manually look up your synapse port in `attributes/ports.rb` in this cookbook.

### How synapse works ###

For every enabled service, synapse looks up a list of available servers which run the service in Zookeeper.
It then configures a local haproxy to forward requests for `localhost`:`synapse_port` to one of those backends (by default, in a round-robin fashion).
Whenever the list of servers for the service changes in zookeeper, synapse reconfigures haproxy to reflect the latest information.

If synapse is not running, haproxy is still running, containing the latest set of servers.
So, even with synapse or zookeeper broken, the list of servers remains reasonably current unless there's massive change.

### How to troubleshoot synapse ###

The immediate course of action is to visit the haproxy stats page.
This is accessible at `your.box:3212` -- just hit it in your web browser.
The stats page will show you all of your enabled services and the backends for those services.
You'll be able to see many per-service and per-backend stats, including the current status and insight into processed requests and how they are doing.

You can restart synapse via the usual way with runit: `sv restart synapse`.
You can also safely reload haproxy if you suspect issues there -- existing connections will be unaffected.

## Nerve ##

[Nerve](https://github.com/airbnb/nerve) is the registration component for synapse.
It takes care of creating entries for your services in Zookeeper.
Your service will be published in zookeeper only when it passes the configured health checks.
When your service stops passing health checks, it will be removed, and placed in maintenance mode in all of it's synapse consumers.

### Using Nerve #####

Using nerve is as simple as [using synapse](#using-synapse).
You just add a `'nerve' => {'enabled_services' => ['your_service']}` section to your `default_attributes` in your role file:

```ruby
name 'myservice'
description 'sets up myservice'

default_attributes({
  'nerve' => { 'enabled_services' => [ 'myservice' ] }
})

run_list(
  'recipe[smartstack]',
  'recipe[myservice]'
)
```

However, you would normally do this if you are writing a role file for your service.
This probably means that you wrote the service as well.
In this case, you'll need to write the [nerve/synapse configuration](#configuring-smartstack) for the service.
You'll also want to make sure that your service has the correct endpoints for [health](#health-checks) and [connectivity](#connectivity-checks) checks.

Once nerve is configured to check your service on your boxes, it will start making health checks.
You can see the health checks being made in nerve's log, in `/etc/service/nerve/log`.

### Configuring Smartstack ###

Smartstack configuration lives in two files in this cookbook.
The first file is `attributes/ports.rb`.
This just contains a port reservation for your service.

The second, more important file, `attributes/services.rb`.
Let's take a look at an example:

```ruby
  'ssspy' => {
    'synapse' => {
      'server_options' => 'check inter 30s downinter 2s fastinter 2s rise 3 fall 1',
      'discovery' => { 'method' => 'zookeeper', },
      'listen' => [
        'mode http',
        'option httpchk GET /ping',
      ],
    },
    'nerve' => {
      'port' => 3260,
      'check_interval' => 2,
      'checks' => [
        { 'type' => 'http', 'uri' => '/health', 'timeout' => 0.5, 'rise' => 2, 'fall' => 1 },
      ]
    },
  },
```

You can see, there are several sections here.
Let's start with the nerve config:

```ruby
    'nerve' => {
      'port' => 3260,
      'check_interval' => 2,
      'checks' => [
        { 'type' => 'http', 'uri' => '/health', 'timeout' => 0.5, 'rise' => 2, 'fall' => 1 },
      ]
    },
```

Nerve here is configured to make it's health checks on port 3260.
This means that `ssspy` is properly running on it's own synapse port locally.
The checks happen every 2 seconds, and there's only one check -- an http check to the `/health` endpoint.

This is the most usual configuration.
However, sometimes you might see multiple checks defined per service.
For instance, here is the config for `flog_thrift`:

```ruby
    'nerve' => {
      'port' => 4567,
      'check_interval' => 1,
      'checks' => [
        { 'type' => 'tcp', 'timeout' => 1, 'rise' => 5, 'fall' => 2 },
        { 'type' => 'http', 'port' => 8422, 'uri' => '/health', 'timeout' => 1, 'rise' => 5, 'fall' => 2 },
      ]
    },
```

For `flog_thift` to be up, it has to both be listening on it's thrift port via TCP and also pass it's http health check.

Lets look at ssspy's synapse config:

```ruby
    'synapse' => {
      'server_options' => 'check inter 30s downinter 2s fastinter 2s rise 3 fall 1',
      'discovery' => {
        'method' => 'zookeeper',
        'hosts' => []
      },
      'listen' => [
        'mode http',
        'option httpchk GET /ping',
      ],
    },
```

The `server_options` directive tells haproxy to run checks on each backend with proper check intervals.
You can read more about the [haproxy check options](https://code.google.com/p/haproxy-docs/wiki/ServerOptions).
The `discovery` section tells us how synapse will find ssspy; in this case, via zookeeper.

Finally, the `listen` section contains additional haproxy configuration.
It specifies how haproxy will conduct it's own health checks.
SSSPy is following convention by properly implemented a `/ping` endpoint for [connectivity checks](#connectivity-checks).

### Health Checks ###

Nobody wants your service to recieve traffic when it's not actually functional.
Your consumers do not want that, because they want their service calls to work.
And you don't want that, because you also want your service to work.

You can make sure that a broken service instance won't recieve traffic by making your `/health` checks fail when your service is broken.
Simply return a non-`200` status code.
Here is an example from [optica](https://github.com/airbnb/optica), a simple Sinatra service:

```ruby
  get '/health' do
    if settings.store.healthy?
      content_type 'text/plain', :charset => 'utf-8'
      return "OK"
    else
      halt(503)
    end
  end
```

The `healthy?` function does [real work](https://github.com/airbnb/optica/blob/164ee747425eb823994345203fd40089751724f5/store.rb#L94) to make sure the service actually functions.
Only nerve will ever hit that endpoint, so you can and should feel free to make it take some time.

### Connectivity Checks ###

If a particular backend for your service passes it's [health checks](#health-checks), it might still be unavailable to consumers.
One example is a network partition -- synapse has discovered your service, but can't actually reach it.
To prevent such problems, we configure the haproxy on the consumer end to do connectivity checks when possible.

We do this by utilizing [haproxy's built-in checking mechanism](http://cbonte.github.io/haproxy-dconv/configuration-1.4.html#5-check).
To destinguish between health checks made by nerve and connectivity checks made by haproxy on the synapse end, we define a `/ping` endpoint.
This endpoint should *always* return `200` with a conventional text body of `PONG`.

Because the number of machines making connectivity checks may be large, you should strive to make the `/ping` check as lightweight as possible.

## Zookeeper and Smartstack ##

Smartstack cannot function without [zookeeper](https://cwiki.apache.org/confluence/display/ZOOKEEPER/ProjectDescription).
This shared file-like store provides the correct semantics for ensuring that service information is correct and distributed across our infrastructure.
We use zookeeper because it provides the [ephemeral nodes](http://zookeeper.apache.org/doc/r3.2.1/zookeeperProgrammers.html#Ephemeral+Nodes) nerve uses to register services.
It's distributed nature prevents it from becoming a scaling choke point or a single points of failure in our infrastructure.

### Debugging Smartstack ###

You would like to use your service from another service, but something is not working.
These instructions will tell you how to debug the situation.

First, on a consumer box (a box which has `the_service` in it's `'synapse' => { 'enabled_services'`) go to port 3212 in your browser.
You'll see the haproxy stats page.
There should be a section for `the_service` containing the boxes providing `the_service`

If the section exists and contains some boxes, but they are all in red, those boxes are failing connectivity checks.
You should double-check your security group settings with SRE.
If the section is not there at all, or is missing some boxes, then there could be two reasons:
1. the service is not properly discovered
2. the service is not properly registered

To check if it's (1), check `synapse` on the consumer box.
1. It should be running; check with `sv s synapse`
2. Try restarting it with `sv restart synapse`
3. Check the synapse logs in `/etc/service/synapse/log/current` for anything unusual

If it looks like synapse is working, then the problem is probably (2) -- no registration.
To debug, follow these steps:

1. Check the service on one of it's instances
  * Is it running? Is it insta-crashing? watch `sv s the_service`
2. If it's insta-crashing, figure out why
  * Check `/etc/service/the_service/logs/current`
  * Run it live; `sv down the_service; cd /etc/service/the_service; ./run`
3. If it's running, is it passing health checks?
  * `curl -D - localhost:32xx/health` and ensure you get a 200
4. Is it passing health checks from a remote box?
  * this happens if you accidentally only bind to `lo` in your service
  * run the health check `curl` from another box
5. Is nerve running?
  * `sv s nerve`; if something is wrong with nerve, alert SRE


You can also smartstack by directly looking in zookeeper for registered services, and watching how that list changes over time.
You can do this via an exhibitor UI.
Another way is to use a zkCli client and connect directly to one of the machines in the cluster.
