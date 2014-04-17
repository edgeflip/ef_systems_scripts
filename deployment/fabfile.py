from fabric.api import *
import instances

STAGING = [
    'edgeflip2-staging-as', 'edgeflip2-staging-celery-as',
    'edgeflip2-staging-rmq-as', 'edgeflip2-staging-fbsync-as'
]
FBSYNC = [
    'eflip-production-fbsync-as', 'eflip-production-comments-fbsync-as',
    'eflip-production-db-fbsync-as', 'eflip-production-lowpri-fbsync-as',
]
TARGETED_CELERY = [
    'eflip-production-celery-as', 'eflip-production-bg-celery-as'
]
TARGETED_WEB = ['eflip-production-as']
TARGETED_SHARING = TARGETED_WEB + TARGETED_CELERY
RMQ = [
    'eflip-production-ebs-fbsync-rmq-as', 'eflip-production-ebs-rmq-as',
]
CONTROLLER = ['eflip-controller-as']
PROD_APPS = CONTROLLER + TARGETED_SHARING + FBSYNC
PROD_ALL = PROD_APPS + RMQ


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
    'edgeflip-staging': hosts(STAGING),
    'edgeflip-fbsync': hosts(FBSYNC),
    'edgeflip-sharing': hosts(TARGETED_SHARING),
    'edgeflip-sharing-celery': hosts(TARGETED_CELERY),
    'edgeflip-sharing-web': hosts(TARGETED_WEB),
    'edgeflip-prod-apps': hosts(PROD_APPS),
    'edgeflip-prod-rmq': hosts(RMQ),
    'edgeflip-prod-all': hosts(PROD_ALL),
}


@task
def restart_puppet():
    sudo('cat /var/run/puppet/agent.pid | xargs kill -HUP')


@task
def remove_configs():
    sudo('rm -rf /root/creds/app')


@task
def health_check():
    sudo('/usr/local/nagios/libexec/check_health')


@task
def check_version():
    run('grep -E "(v[0-9]+\.[0-9]+.[0-9]+)" /var/www/edgeflip/app_info.json -o')


@task
@parallel
def kick():
    remove_configs()
    restart_puppet()


@task
def rolling_kick():
    remove_configs
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
