from fabric.api import *
import instances

def hosts(group_names):
    """ return a callable that generates a list of hostnames when evaluated. """
    def _get_hosts():
        as_groups = group_names
        hosts = []
        for group in as_groups:
            nodes = instances.from_as_group(group)
            hosts.extend(nodes)
        return hosts
    return _get_hosts

env.roledefs = {
    'edgeflip-production': hosts(['edgeflip-production-as']),
    'edgeflip-staging': hosts(['edgeflip-staging-as'])

}

@task
def restart_puppet():
    sudo('cat /var/run/puppet/agent.pid | xargs kill -HUP')

@task
def health_check():
    sudo('/usr/local/nagios/libexec/check_health')

@task
@parallel
def kick():
    restart_puppet()

@task
def rolling_kick():
    restart_puppet()
    wait(5)

@task
def update_geppetto():
    sync_repo()
    show_sync_logs()
    restart_puppet()
    wait(30)
    restart_apache()

@task
def touch_uwsgi():
    sudo('touch /etc/uwsgi/emperor/*.ini')

@task
def rolling_touch():
    touch_uwsgi()
    wait(10)
