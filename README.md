zero-to-dockerized-phoenix-cluster
----------------------------------

CoreOS + Kubernetes + Phoenix on [Digital Ocean](https://www.digitalocean.com/?refcode=842fc3e1bfa6)

# Goals

Full stack on Digital Ocean

- [x] dockerize Phoenix app
- [ ] Postgresql cluster
- [ ] dockerize NGINX
- [ ] app registration discovery for nginx load balancer(done by confd)
- [ ] use vulcand instead of nginx load balancer
- [ ] configure DroneCI via fleet unit file (drone_conf.toml)
- [ ] continuos deployment

# Setup Kubernetes

### STEP1) Setup digitalocean

Given that you already have exported DIGITAL_OCEAN_TOKEN
and you already have installed docker-machine locally,

```
cd bin
./deploy.sh -n 3 -t $DIGITAL_OCEAN_TOKEN -s 4gb -r sgp1 -o <name>

```

This will create 3 ditital ocean droplets 
and create ssh key / cert files. 

### STEP2) Kubernetes

[x] [self signed certificates](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html)
[x] [customize docker](https://coreos.com/os/docs/latest/customizing-docker.html)
[ ] [access docker hub](https://coreos.com/os/docs/latest/registry-authentication.html)
[ ] [kubernetes](https://coreos.com/kubernetes/docs/latest/getting-started.html)

### STEP3) DNS Setup (namecheap)

Once the droplet is up and running you should have an IP address to work with. If you're using namecheap, go to the "All Host Records" page of namecheap's "My Account > Manage Domains > Modify Domain" section.

You'll need an A record for the naked domain (the "@" one) pointing to your IP with the lowest TTL possible (namecheap caps the minimum at 60), and a wildcard for subdomains with the same info. I'd recommend redirecting www to the naked domain.

It should look something like this when you're done entering your data.

| HOST NAME | IP ADDRESS/URL | RECORD TYPE | MX PREF | TTL |
| --- | --- | --- | --- | --- |
| @ | your.ip.address.k.thx | A (Address) | n/a | 60 |
| www | http://your.domain | URL Redirect (301) | n/a | 60 |
| * | your.ip.address.k.thx | A (Address) | n/a | 60 |

# Deploy steps

Add Dockerfile in your phoenix app

```
FROM 19hz/phoenix:latest
MAINTAINER Jaigouk Kim @jaigouk

WORKDIR /usr/src/app
ENV SECRET_KEY_BASE=xxxx
ENV DB_POOL_SIZE=20
ENV PORT=4001
EXPOSE 4001
CMD ["mix", "phoenix.server"]
```

# References

[Generate Self Signed Certificates](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html)

[CoreOS Cloud config](https://github.com/coreos/coreos-cloudinit/blob/master/Documentation/cloud-config.md#users)

[String Tricks that Bash Knows](http://spin.atomicobject.com/2014/02/16/bash-string-maniuplation/)

[Giant swarm blog: Getting Started with Microservices using Ruby on Rails and Docker](http://blog.giantswarm.io/getting-started-with-microservices-using-ruby-on-rails-and-docker)

[martinfowler: microservice-testing](http://martinfowler.com/articles/microservice-testing/)

[Rainforest: Docker in Action - Development to Delivery, Part 2](https://blog.rainforestqa.com/2014-12-08-docker-in-action-from-deployment-to-delivery-part-2-continuous-integration/)
